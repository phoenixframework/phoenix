defmodule Phoenix.Transports.LongPoll do
  @moduledoc """
  Handles LongPoll clients for the Channel Transport layer.

  ## Configuration

  The long poller is configurable in your Socket's transport configuration:

      transport :longpoll, Phoenix.Transports.LongPoll,
        window_ms: 10_000,
        pubsub_timeout_ms: 1000,
        crypto: [iterations: 1000,
                 length: 32,
                 digest: :sha256,
                 cache: Plug.Keys],

    * `:window_ms` - how long the client can wait for new messages
      in it's poll request.
    * `:pubsub_timeout_ms` - how long a request can wait for the
      pubsub layer to respond.
    * `:crypto` - configuration for the key generated to sign the
      private topic used for the long poller session (see `Plug.Crypto.KeyGenerator`).
  """
  use Plug.Builder

  @behaviour Phoenix.Channel.Transport

  import Phoenix.Controller
  alias Phoenix.Socket.Message
  alias Phoenix.Transports.LongPoll
  alias Phoenix.Channel.Transport


  plug :fetch_query_params
  plug :check_origin
  plug :allow_origin
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :dispatch

  @doc """
  Provides the deault transport configuration to sockets.

  * `:serializer` - The `Phoenix.Socket.Message` serializer
  * `:pubsub_timeout_ms` - The timeout to wait for the LongPoll.Server ack
  * `:log` - The log level, for example `:info`. Disabled by default
  * `:timeout` - The connection timeout in milliseconds, defaults to `:infinity`
  * `:crypto` - The list of encryption options for the `Plug.Session`
  """
  def default_config() do
    [window_ms: 10_000,
     pubsub_timeout_ms: 1000,
     serializer: Phoenix.Transports.LongPollSerializer,
     log: false,
     crypto: [iterations: 1000, length: 32,
              digest: :sha256, cache: Plug.Keys]]
  end

  def handler_for(:cowboy), do: Plug.Adapters.Cowboy.Handler

  defp dispatch(%Plug.Conn{method: "OPTIONS"} = conn, _) do
    options(conn, conn.params)
  end
  defp dispatch(%Plug.Conn{method: "GET"} = conn, _) do
    poll(conn, conn.params)
  end
  defp dispatch(%Plug.Conn{method: "POST"} = conn, _) do
    publish(conn, conn.params)
  end
  defp dispatch(conn, _) do
    conn |> send_resp(:bad_request, "") |> halt()
  end

  def call(conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)
    put_in(conn.secret_key_base, endpoint.config(:secret_key_base))
    |> put_private(:phoenix_endpoint, endpoint)
    |> put_private(:phoenix_transport_conf, opts)
    |> put_private(:phoenix_socket_handler, handler)
    |> super(opts)
  end

  @doc """
  Responds to pre-flight CORS requests with Allow-Origin-* headers.
  """
  def options(conn, _params) do
    send_resp(conn, :ok, "")
  end

  @doc """
  Listens for `%Phoenix.Socket.Message{}`'s from `Phoenix.LongPoll.Server`.

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
    handler  = conn.private.phoenix_socket_handler

    case Transport.socket_connect(endpoint_module(conn), Phoenix.Transports.LongPoll, handler, conn.params) do
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

    case transport_dispatch(conn, priv_topic, msg) do
      :ok               -> conn |> put_status(:ok) |> status_json(%{})
      {:error, _reason} -> conn |> put_status(:unauthorized) |> status_json(%{})
    end
  end

  ## Client

  @doc """
  Starts the `Phoenix.LongPoll.Server` and stores the serialized pid in the session.
  """
  def start_session(conn, socket) do
    priv_topic =
      "phx:lp:"
      |> Kernel.<>(Base.encode64(:crypto.strong_rand_bytes(16)))
      |> Kernel.<>(:os.timestamp() |> Tuple.to_list |> Enum.join(""))

    child = [socket, timeout_window_ms(conn), priv_topic]
    {:ok, server_pid} = Supervisor.start_child(LongPoll.Supervisor, child)

    {conn, priv_topic, sign(conn, priv_topic), server_pid}
  end

  @doc """
  Finds the `Phoenix.LongPoll.Server` server from the session.
  """
  def resume_session(conn) do
    case verify_longpoll_topic(conn) do
      {:ok, priv_topic}     -> {:ok, conn, priv_topic}
      :notopic              -> {:error, conn, :terminated}
      {:error, :terminated} -> {:error, conn, :terminated}
    end
  end

  @doc """
  Retrieves the serialized `Phoenix.LongPoll.Server` pid from the encrypted token.
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
  Ack's a list of message refs back to the `Phoenix.LongPoll.Server`.

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
  `Phoenix.LongPoll.Server`
  """
  def transport_dispatch(conn, priv_topic, msg) do
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
    Keyword.fetch!(conn.private.phoenix_transport_conf, :window_ms)
  end

  defp pubsub_timeout_ms(conn) do
    Keyword.fetch!(conn.private.phoenix_transport_conf, :pubsub_timeout_ms)
  end

  defp pubsub_server(conn), do: endpoint_module(conn).__pubsub_server__()

  defp subscribe(conn, priv_topic) do
    Phoenix.PubSub.subscribe(pubsub_server(conn), self, priv_topic, link: true)
  end

  defp broadcast_from(conn, priv_topic, msg) do
    Phoenix.PubSub.broadcast_from(pubsub_server(conn), self, priv_topic, msg)
  end

  defp check_origin(conn, _opts) do
    allowed_origins = conn.private.phoenix_transport_conf[:origins]
    Transport.check_origin(conn, allowed_origins, send: &status_json(&1, %{}))
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
    crypto_opts = Keyword.fetch!(conn.private.phoenix_transport_conf, :crypto)
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
