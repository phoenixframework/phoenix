defmodule Phoenix.Transports.Detached do
  @moduledoc false
  #
  # Detached sessions, see Phoenix.Socket.start_detached/3.
  #
  # The client attaches to the session with its token like it resumes a session, over
  # a WebSocket or with long polling. The socket must be resumable, as a WebSocket that
  # is not resumable treats the attaching client as a new connection.

  alias Phoenix.Socket.Transport
  alias Phoenix.Transports.{Session, WebSocket}

  def start(%Plug.Conn{} = conn, endpoint, path, opts \\ []) do
    with :ok <- check_limit(Keyword.get(opts, :max_pending)),
         {:ok, handler, transport_opts, resumable} <- socket_config(endpoint, path),
         config = connect_config(conn, endpoint, transport_opts),
         {:ok, handler_state} <- connect(handler, config),
         :ok <- check_resumable(resumable, config) do
      transport_opts = Keyword.merge(transport_opts, Keyword.take(opts, [:window_ms]))

      case Session.start(endpoint, handler, handler_state, :detached, transport_opts) do
        {:ok, session, priv_topic} ->
          data = {:v1, endpoint.config(:endpoint_id), session, priv_topic}
          {:ok, session, Session.sign_token(endpoint, data, transport_opts)}

        {:error, _} = error ->
          error
      end
    end
  end

  def join(session, topic, payload, assigns) do
    ref = Process.monitor(session)
    send(session, {Phoenix.Socket, :join, {self(), ref}, topic, payload, assigns})

    receive do
      {^ref, :ok, join_ref} ->
        Process.demonitor(ref, [:flush])
        {:ok, join_ref}

      {^ref, :error, reply} ->
        Process.demonitor(ref, [:flush])
        {:error, reply}

      {:DOWN, ^ref, _, _, _} ->
        {:error, %{reason: "join crashed"}}
    end
  end

  # The sessions register themselves, so the count can exceed the limit when requests
  # start sessions concurrently. That is fine, as the limit only sheds load.
  def count do
    Registry.count(__MODULE__.Registry)
  end

  defp check_limit(nil), do: :ok

  defp check_limit(max) when is_integer(max) and max >= 0 do
    if count() < max, do: :ok, else: {:error, :limit}
  end

  defp check_limit(other) do
    raise ArgumentError, ":max_pending must be a non-negative integer, got: #{inspect(other)}"
  end

  def stop(session) do
    GenServer.stop(session, {:shutdown, :closed})
  catch
    :exit, _ -> :ok
  end

  # The config of the transport that signs the token. Both transports
  # must use the same :crypto options to resume each other's sessions.
  defp socket_config(endpoint, path) do
    case Phoenix.Endpoint.__socket_config__(endpoint, path) do
      %{handler: handler, websocket: websocket, longpoll: longpoll} ->
        # long polling always resumes
        resumable = if websocket, do: Keyword.get(websocket, :resumable, false), else: true

        cond do
          not function_exported?(handler, :__channel__, 1) -> {:error, :not_a_phoenix_socket}
          resumable == false -> {:error, :not_resumable}
          true -> {:ok, handler, websocket || longpoll, resumable}
        end

      nil ->
        {:error, :no_socket}
    end
  end

  defp connect_config(conn, endpoint, transport_opts) do
    keys = Keyword.get(transport_opts, :connect_info, [])
    # the request is not a cross-site request, unlike a WebSocket connection
    connect_info = Transport.connect_info(conn, endpoint, keys, check_csrf: false)

    %{
      endpoint: endpoint,
      transport: :detached,
      options: transport_opts,
      params: %{"vsn" => "2.0.0"},
      connect_info: put_session(connect_info, conn)
    }
  end

  # The request can change its session before it starts the session, for example
  # when it logs the user in, so we prefer it over the session of its cookie.
  defp put_session(%{session: _} = connect_info, %{private: %{plug_session_fetch: :done}} = conn) do
    %{connect_info | session: Plug.Conn.get_session(conn)}
  end

  defp put_session(connect_info, _conn), do: connect_info

  defp connect(handler, config) do
    case handler.connect(config) do
      {:ok, handler_state} -> {:ok, handler_state}
      :error -> {:error, :rejected}
      {:error, reason} -> {:error, reason}
    end
  end

  # A :resumable function decides after the socket accepted the connection,
  # like it does for a new WebSocket.
  defp check_resumable(resumable, config) do
    if WebSocket.resumable?(resumable, config), do: :ok, else: {:error, :denied}
  end
end
