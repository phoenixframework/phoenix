defmodule Phoenix.Transports.LongPoller do
  use Phoenix.Controller

  @moduledoc false

  alias Phoenix.Socket.Message
  alias Poison, as: JSON
  alias Phoenix.Transports.LongPoller

  plug :fetch_session
  plug :action

  @doc """
  Starts `Phoenix.LongPoller.Server` and stores pid in session. This action must
  be called first before sending requests to `poll` or `publish`
  """
  def open(conn, _) do
    {conn, _server_pid} = resume_session(conn)
    send_resp(conn, :ok, "")
  end

  @doc """
  Listens for `%Phoenix.Socket.Message{}`'s from `Phoenix.LongPoller.Server`.

  As soon as messages are received, they are encoded as JSON and send down
  to the longpolling client, which immediately repolls. If a timeout occurrs,
  a `:no_content` response is returned, and the client should immediately repoll.
  """
  def poll(conn, _params) do
    {conn, server_pid} = resume_session(conn)
    listen(conn, server_pid)
  end
  defp listen(conn, server_pid) do
    timeout_ms = timeout_window_ms(conn)
    set_active_listener(server_pid, self)

    receive do
      {:messages, msgs} ->
        ack(server_pid, msgs)
        json(conn, JSON.encode!(msgs))
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
    {conn, server_pid} = resume_session(conn)
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
    {:ok, server_pid} = LongPoller.Server.start(router, timeout_window_ms(conn))
    conn = put_session(conn, session_key(conn), :erlang.term_to_binary(server_pid))

    {conn, server_pid}
  end

  @doc """
  Finds or starts the `Phoenix.LongPoller.Server` server
  """
  def resume_session(conn) do
    {conn, server_pid} = case longpoll_pid(conn) do
      nil -> start_session(conn)
      pid -> {conn, pid}
    end

    {conn, server_pid}
  end

  @doc """
  Retrieves the serialized `Phoenix.LongPoller.Server` pid from the session
  """
  def longpoll_pid(conn) do
    case get_session(conn, session_key(conn)) do
      nil -> nil
      bin ->
        pid = :erlang.binary_to_term(bin)
        if Process.alive?(pid), do: pid, else: nil
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
    get_in router_module(conn).config(:transports), [:longpoller, :window_ms]
  end
end
