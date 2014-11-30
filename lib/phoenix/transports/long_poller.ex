defmodule Phoenix.Transports.LongPoller do
  use Phoenix.Controller

  @moduledoc false

  alias Phoenix.Socket.Message
  alias Phoenix.Transports.LongPoller

  plug :fetch_session
  plug :action

  @doc """
  Starts `Phoenix.LongPoller.Server` and stores pid in session. This action must
  be called first before sending requests to `poll` or `publish`
  """
  def open(conn, _) do
    {conn, _server_pid} = start_session(conn)
    send_resp(conn, :ok, "")
  end

  @doc """
  Listens for `%Phoenix.Socket.Message{}`'s from `Phoenix.LongPoller.Server`.

  As soon as messages are received, they are encoded as JSON and send down
  to the longpolling client, which immediately repolls. If a timeout occurrs,
  a `:no_content` response is returned, and the client should immediately repoll.
  """
  def poll(conn, _params) do
    case resume_session(conn) do
      {:ok, conn, server_pid}     -> listen(conn, server_pid)
      {:error, conn, :terminated} -> send_resp(conn, :gone, "")
    end
  end
  defp listen(conn, server_pid) do
    timeout_ms = timeout_window_ms(conn)
    set_active_listener(server_pid, self)

    receive do
      {:messages, msgs} ->
        ack(server_pid, msgs)
        json(conn, msgs)
    after
      timeout_ms ->
        ack(server_pid, [])
        send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Publishes a `%Phoenix.Socket.Message{}` to a channel

  If the message was authorized by the Channel, a 200 OK response is returned,
  otherwise a 401 Unauthorized response is returned
  """
  def publish(conn, message) do
    case resume_session(conn) do
      {:ok, conn, server_pid}     -> dispatch_publish(conn, message, server_pid)
      {:error, conn, :terminated} -> send_resp(conn, :gone, "")
    end
  end
  defp dispatch_publish(conn, message, server_pid) do
    msg = Message.from_map!(message)

    case dispatch(server_pid, msg) do
      {:ok, _socket}             -> send_resp(conn, :ok, "")
      {:error, _socket, _reason} -> send_resp(conn, :unauthorized, "")
    end
  end


  ## Client

  @doc """
  Starts the `Phoenix.LongPoller.Server` and stores the serialized pid in the session
  """
  def start_session(conn) do
    router = router_module(conn)
    child  = [router, timeout_window_ms(conn)]
    {:ok, server_pid} = Supervisor.start_child(LongPoller.Supervisor, child)
    conn = put_session_with_salt(conn, server_pid)

    {conn, server_pid}
  end

  # Serialized longpoll server pid into session and harden with random salt
  defp put_session_with_salt(conn, server_pid) do
    key = session_key(conn)
    conn
    |> put_session(key, :erlang.term_to_binary(server_pid))
    |> put_session("#{key}_salt", :crypto.strong_rand_bytes(16) |> Base.encode64)
  end

  @doc """
  Finds the `Phoenix.LongPoller.Server` server from the session
  """
  def resume_session(conn) do
    case longpoll_pid(conn) do
      {:ok, pid}            -> {:ok, conn, pid}
      :nopid                -> {:error, conn, :terminated}
      {:error, :terminated} -> {:error, conn, :terminated}
    end
  end

  @doc """
  Retrieves the serialized `Phoenix.LongPoller.Server` pid from the session
  """
  def longpoll_pid(conn) do
    case get_session(conn, session_key(conn)) do
      nil -> :nopid
      bin ->
        pid = :erlang.binary_to_term(bin)
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, :terminated}
        end
    end
  end

  @doc """
  Ack's a list of `%Phoenix.Socket.Messages{}`'s back to the `Phoenix.LongPoller.Server`

  To be called after buffered messages have been relayed to client
  """
  def ack(server_pid, messages) do
    :ok = GenServer.call(server_pid, {:ack, messages})
  end

  defp session_key(conn), do: :"#{router_module(conn)}_longpoll_pid"

  @doc """
  Sets the active listener process. Called by polling `conn`
  """
  def set_active_listener(server_pid, listener_pid) do
    GenServer.call(server_pid, {:set_active_listener, listener_pid})
  end

  @doc """
  Dispatches deserialized `%Phoenix.Socket.Message{}` from client to
  `Phoenix.LongPoller.Server`
  """
  def dispatch(server_pid, message) do
    GenServer.call(server_pid, {:dispatch, message})
  end

  defp timeout_window_ms(conn) do
    get_in router_module(conn).config(:transports), [:longpoller_window_ms]
  end
end
