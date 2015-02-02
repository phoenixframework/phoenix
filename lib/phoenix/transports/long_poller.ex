defmodule Phoenix.Transports.LongPoller do
  use Phoenix.Controller

  @moduledoc false

  @pubsub_timeout_ms 1000

  alias Phoenix.Socket.Message
  alias Phoenix.Transports.LongPoller

  # TODO: If we are going to decouple this from the router,
  # we need to plug the parameter parser and use its own
  # session thing

  plug :fetch_session
  plug :action

  @doc """
  Starts `Phoenix.LongPoller.Server` and stores pid in session. This action must
  be called first before sending requests to `poll` or `publish`
  """
  def open(conn, _) do
    {conn, _priv_topic, _server_pid} = start_session(conn)
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
      {:ok, conn, priv_topic}     -> listen(conn, priv_topic)
      {:error, conn, :terminated} -> send_resp(conn, :gone, "")
    end
  end
  defp listen(conn, priv_topic) do
    timeout_ms = timeout_window_ms(conn)
    flush_local_buffer()
    :ok = broadcast_from(conn, priv_topic, :flush)

    receive do
      {:messages, msgs} ->
        :ok = ack(conn, priv_topic, msgs)
        json(conn, msgs)
    after
      timeout_ms ->
        :ok = ack(conn, priv_topic, [])
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
      {:ok, conn, priv_topic}     -> dispatch_publish(conn, message, priv_topic)
      {:error, conn, :terminated} -> send_resp(conn, :gone, "")
    end
  end

  defp dispatch_publish(conn, message, priv_topic) do
    msg = Message.from_map!(message)

    case dispatch(conn, priv_topic, msg) do
      :ok               -> send_resp(conn, :ok, "")
      {:error, _reason} -> send_resp(conn, :unauthorized, "")
    end
  end

  ## Client

  @doc """
  Starts the `Phoenix.LongPoller.Server` and stores the serialized pid in the session
  """
  def start_session(conn) do
    router = router_module(conn)
    priv_topic =
      "phx:lp:"
      |> Kernel.<>(Base.encode64(:crypto.strong_rand_bytes(16)))
      |> Kernel.<>(:os.timestamp() |> Tuple.to_list |> Enum.join(""))

    child = [router, timeout_window_ms(conn), priv_topic, pubsub_server(conn)]
    {:ok, server_pid} = Supervisor.start_child(LongPoller.Supervisor, child)
    conn = put_session(conn, session_key(conn), priv_topic)

    {conn, priv_topic, server_pid}
  end

  @doc """
  Finds the `Phoenix.LongPoller.Server` server from the session
  """
  def resume_session(conn) do
    case longpoll_topic(conn) do
      {:ok, priv_topic}     -> {:ok, conn, priv_topic}
      :notopic              -> {:error, conn, :terminated}
      {:error, :terminated} -> {:error, conn, :terminated}
    end
  end

  @doc """
  Retrieves the serialized `Phoenix.LongPoller.Server` pid from the session
  """
  def longpoll_topic(conn) do
    case get_session(conn, session_key(conn)) do
      nil -> :notopic
      priv_topic ->
        :ok = subscribe(conn, priv_topic)
        :ok = broadcast_from(conn, priv_topic, :ping)
        receive do
          :pong -> {:ok, priv_topic}
        after
          @pubsub_timeout_ms  -> {:error, :terminated}
        end
    end
  end

  @doc """
  Ack's a list of `%Phoenix.Socket.Messages{}`'s back to the `Phoenix.LongPoller.Server`

  To be called after buffered messages have been relayed to client
  """
  def ack(conn, priv_topic, messages) do
    :ok = broadcast_from(conn, priv_topic, {:ack, messages})
    receive do
      {:ok, :ack} -> :ok
    after
      @pubsub_timeout_ms -> :error
    end
  end

  defp session_key(conn), do: "#{router_module(conn)}_longpoll_topic"

  @doc """
  Dispatches deserialized `%Phoenix.Socket.Message{}` from client to
  `Phoenix.LongPoller.Server`
  """
  def dispatch(conn, priv_topic, msg) do
    :ok = broadcast_from(conn, priv_topic, {:dispatch, msg})
    receive do
      {:ok, :dispatch}            -> :ok
      {:error, :dispatch, reason} -> {:error, reason}
    after
      @pubsub_timeout_ms -> {:error, :timeout}
    end
  end

  defp timeout_window_ms(conn) do
    get_in endpoint_module(conn).config(:transports), [:longpoller_window_ms]
  end

  defp pubsub_server(conn), do: router_module(conn).pubsub_server()

  defp flush_local_buffer do
    receive do
      {:messages, _msgs} -> flush_local_buffer()
    after 0 -> :ok
    end
  end

  defp subscribe(conn, priv_topic) do
    Phoenix.PubSub.subscribe(pubsub_server(conn), self, priv_topic)
  end

  defp broadcast_from(conn, priv_topic, msg) do
    Phoenix.PubSub.broadcast_from(pubsub_server(conn), self, priv_topic, msg)
  end
end
