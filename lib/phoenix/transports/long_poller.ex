defmodule Phoenix.Transports.LongPoller do
  use Phoenix.Controller

  @moduledoc """
  Handles LongPoller clients for the Channel Transport layer.

  ## Configuration

  The long poller is configurable via the Endpoint's transport configuration:

      config :my_app, MyApp.Endpoint, transports: [
        longpoller_window_ms: 10_000,
        longpoller_pubsub_timeout_ms: 1000,
        longpoller_crypto: [iterations: 1000,
                            length: 32,
                            digest: :sha256,
                            cache: Plug.Keys],
      ]

    * `:longpoller_window_ms` - how long the client can wait for new messages
      in it's poll request.
    * `:longpoller_pubsub_timeout_ms` - how long a request can wait for the
      pubsub layer to respond.
    * `:longpoller_crypto` - configuration for the key generated to sign the
      private topic used for the long poller session (see `Plug.Crypto.KeyGenerator`).
  """

  alias Phoenix.Socket.Message
  alias Phoenix.Transports.LongPoller
  alias Phoenix.Channel.Transport

  plug :check_origin
  plug :allow_origin

  plug Plug.Parsers, parsers: [:json], json_decoder: Poison

  @doc """
  Responds to pre-flight CORS requests with Allow-Origin-* headers.
  """
  def options(conn, _params) do
    send_resp(conn, :ok, "")
  end

  @doc """
  Listens for `%Phoenix.Socket.Message{}`'s from `Phoenix.LongPoller.Server`.

  As soon as messages are received, they are encoded as JSON and sent down
  to the longpolling client, which immediately repolls. If a timeout occurs,
  a `:no_content` response is returned, and the client should immediately repoll.
  """
  def poll(conn, _params) do
    case resume_session(conn) do
      {:ok, conn, priv_topic} ->
        listen(conn, priv_topic)
      {:error, conn, :terminated} ->
        new_session(conn)
    end
  end

  defp listen(conn, priv_topic) do
    ref = :erlang.make_ref()
    :ok = broadcast_from(conn, priv_topic, {:flush, ref})

    receive do
      {:messages, msgs, ^ref} ->
        :ok = ack(conn, priv_topic, msgs)
        status_json(conn, %{messages: msgs, token: conn.params["token"], sig: conn.params["sig"]})
    after
      timeout_window_ms(conn) ->
        :ok = ack(conn, priv_topic, [])
        conn
        |> put_status(:no_content)
        |> status_json(%{token: conn.params["token"], sig: conn.params["sig"]})
    end
  end

  defp new_session(conn) do
    case conn.private.phoenix_socket_handler.connect(conn.params, %Phoenix.Socket{}) do
      {:ok, socket} ->
        {conn, priv_topic, sig, _server_pid} = start_session(conn, socket)

        conn
        |> put_status(:gone)
        |> status_json(%{token: priv_topic, sig: sig})

      :error ->
        conn |> put_status(:forbidden) |> status_json(%{})
    end
  end

  @doc """
  Publishes a `%Phoenix.Socket.Message{}` to a channel.

  If the message was authorized by the Channel, a 200 OK response is returned,
  otherwise a 401 Unauthorized response is returned.
  """
  def publish(conn, message) do
    case resume_session(conn) do
      {:ok, conn, priv_topic}     -> dispatch_publish(conn, message, priv_topic)
      {:error, conn, :terminated} -> conn |> put_status(:gone) |> status_json(%{})
    end
  end

  defp dispatch_publish(conn, message, priv_topic) do
    msg = Message.from_map!(message)

    case dispatch(conn, priv_topic, msg) do
      :ok               -> conn |> put_status(:ok) |> status_json(%{})
      {:error, _reason} -> conn |> put_status(:unauthorized) |> status_json(%{})
    end
  end

  ## Client

  @doc """
  Starts the `Phoenix.LongPoller.Server` and stores the serialized pid in the session.
  """
  def start_session(conn, socket) do
    socket_handler = conn.private.phoenix_socket_handler
    priv_topic =
      "phx:lp:"
      |> Kernel.<>(Base.encode64(:crypto.strong_rand_bytes(16)))
      |> Kernel.<>(:os.timestamp() |> Tuple.to_list |> Enum.join(""))

    child = [socket_handler, socket, timeout_window_ms(conn), priv_topic, endpoint_module(conn)]
    {:ok, server_pid} = Supervisor.start_child(LongPoller.Supervisor, child)

    {conn, priv_topic, sign(conn, priv_topic), server_pid}
  end

  @doc """
  Finds the `Phoenix.LongPoller.Server` server from the session.
  """
  def resume_session(conn) do
    case verify_longpoll_topic(conn) do
      {:ok, priv_topic}     -> {:ok, conn, priv_topic}
      :notopic              -> {:error, conn, :terminated}
      {:error, :terminated} -> {:error, conn, :terminated}
    end
  end

  @doc """
  Retrieves the serialized `Phoenix.LongPoller.Server` pid from the encrypted token.
  """
  def verify_longpoll_topic(%Plug.Conn{params: %{"token" => token, "sig" => sig}} = conn) do
    case verify(conn, token, sig) do
      {:ok, priv_topic} ->
        ref = :erlang.make_ref()
        :ok = subscribe(conn, priv_topic)
        :ok = broadcast_from(conn, priv_topic, {:subscribe, ref})
        receive do
          {:ok, :subscribe, ^ref} -> {:ok, priv_topic}
        after
          pubsub_timeout_ms(conn)  -> {:error, :terminated}
        end

      _ -> :notopic
    end
  end
  def verify_longpoll_topic(_conn), do: :notopic

  @doc """
  Ack's a list of message refs back to the `Phoenix.LongPoller.Server`.

  To be called after buffered messages have been relayed to the client.
  """
  def ack(conn, priv_topic, msgs) do
    ref = :erlang.make_ref()
    :ok = broadcast_from(conn, priv_topic, {:ack, Enum.count(msgs), ref})
    receive do
      {:ok, :ack, ^ref} -> :ok
    after
      pubsub_timeout_ms(conn) -> :error
    end
  end

  @doc """
  Dispatches deserialized `%Phoenix.Socket.Message{}` from client to
  `Phoenix.LongPoller.Server`
  """
  def dispatch(conn, priv_topic, msg) do
    ref = :erlang.make_ref()
    :ok = broadcast_from(conn, priv_topic, {:dispatch, msg, ref})
    receive do
      {:ok, :dispatch, ^ref}            -> :ok
      {:error, :dispatch, reason, ^ref} -> {:error, reason}
    after
      pubsub_timeout_ms(conn) -> {:error, :timeout}
    end
  end

  defp timeout_window_ms(conn) do
    get_in endpoint_module(conn).config(:transports), [:longpoller_window_ms]
  end

  defp pubsub_timeout_ms(conn) do
    get_in endpoint_module(conn).config(:transports), [:longpoller_pubsub_timeout_ms]
  end

  defp pubsub_server(conn), do: endpoint_module(conn).__pubsub_server__()

  defp subscribe(conn, priv_topic) do
    Phoenix.PubSub.subscribe(pubsub_server(conn), self, priv_topic, link: true)
  end

  defp broadcast_from(conn, priv_topic, msg) do
    Phoenix.PubSub.broadcast_from(pubsub_server(conn), self, priv_topic, msg)
  end

  defp check_origin(conn, _opts) do
    Transport.check_origin(conn, send: &status_json(&1, %{}))
  end

  defp sign(conn, priv_topic) do
    salt = derive_salt(conn, to_string(pubsub_server(conn)))
    Plug.Crypto.MessageVerifier.sign(priv_topic, salt)
  end

  defp verify(conn, priv_topic, sig) do
    salt = derive_salt(conn, to_string(pubsub_server(conn)))
    case Plug.Crypto.MessageVerifier.verify(sig, salt) do
      {:ok, ^priv_topic} -> {:ok, priv_topic}
      _ -> :error
    end
  end

  defp derive_salt(%Plug.Conn{secret_key_base: base}, _key)
    when base == nil or byte_size(base) < 64 do

    raise "conn.secret_key_base must be at least 64 bytes for longpoll token verification"
  end
  defp derive_salt(conn, key) do
    crypto_opts = get_in(endpoint_module(conn).config(:transports), [:longpoller_crypto])

    Plug.Crypto.KeyGenerator.generate(conn.secret_key_base, key, crypto_opts)
  end

  defp allow_origin(conn, _opts) do
    headers = get_req_header(conn, "access-control-request-headers") |> Enum.join(", ")

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", headers)
    |> put_resp_header("access-control-allow-methods", "get, post, options")
    |> put_resp_header("access-control-max-age", "3600")
  end

  defp status_json(conn, map) do
    status = Plug.Conn.Status.code(conn.status || 200)
    map = Map.put(map, :status, status)
    conn
    |> put_status(:ok)
    |> json(map)
  end
end
