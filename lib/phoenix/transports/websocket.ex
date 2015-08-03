defmodule Phoenix.Transports.WebSocket do
  @moduledoc """
  Handles WebSocket clients for the Channel Transport layer.

  ## Configuration

  By default, JSON encoding is used to broker messages to and from clients and
  Websockets, by default, do not timeout if the connection is lost. The
  maximum timeout duration and serializer can be configured in your Socket's
  transport configuration:

      transport :websocket, Phoenix.Transports.WebSocket,
        serializer: MySerializer
        timeout: 60000

  The `serializer` module needs only to implement the `encode!/1` and
  `decode!/2` functions defined by the `Phoenix.Transports.Serializer` behaviour.
  """
  @behaviour Phoenix.Channel.Transport

  import Plug.Conn, only: [fetch_query_params: 1, send_resp: 3]

  alias Phoenix.Socket.Broadcast
  alias Phoenix.Channel.Transport

  def init(%Plug.Conn{method: "GET"} = conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)

    conn =
      conn
      |> Plug.Conn.fetch_query_params
      |> Transport.check_origin(opts[:origins])

    case conn do
      %{halted: false} = conn ->
        params     = conn.params
        serializer = Keyword.fetch!(opts, :serializer)

        case Transport.connect(endpoint, handler, transport, __MODULE__, serializer, params) do
          {:ok, socket} ->
            {:ok, conn, {__MODULE__, {socket, opts}}}
          :error ->
            send_resp(conn, 403, "")
            {:error, conn}
        end
      %{halted: true} = conn ->
        {:error, conn}
    end
  end

  def init(conn, _) do
    send_resp(conn, :bad_request, "")
    {:error, conn}
  end

  @doc """
  Provides the deault transport configuration to sockets.

  * `:serializer` - The `Phoenix.Socket.Message` serializer
  * `:log` - The log level, for example `:info`. Disabled by default
  * `:timeout` - The connection timeout in milliseconds, defaults to `:infinity`
  """
  def default_config() do
    [serializer: Phoenix.Transports.WebSocketSerializer,
     timeout: :infinity,
     log: false]
  end

  def handler_for(:cowboy), do: Phoenix.Endpoint.CowboyWebSocket

  @doc """
  Handles initalization of the websocket.
  """
  def ws_init({socket, config}) do
    Process.flag(:trap_exit, true)
    serializer = Keyword.fetch!(config, :serializer)
    timeout    = Keyword.fetch!(config, :timeout)

    if socket.id, do: socket.endpoint.subscribe(self, socket.id, link: true)

    {:ok, %{socket: socket,
            sockets: HashDict.new,
            sockets_inverse: HashDict.new,
            serializer: serializer}, timeout}
  end

  @doc """
  Receives JSON encoded `%Phoenix.Socket.Message{}` from client and dispatches
  to Transport layer.
  """
  def ws_handle(opcode, payload, state) do
    msg = state.serializer.decode!(payload, opcode: opcode)

    case Transport.dispatch(msg, state.sockets, self, state.socket) do
      {:ok, socket_pid, reply_msg} ->
        format_reply(state.serializer.encode!(reply_msg), put(state, msg.topic, socket_pid))
      {:ok, reply_msg} ->
        format_reply(state.serializer.encode!(reply_msg), state)
      :ok ->
        {:ok, state}
      {:error, _reason, error_reply_msg} ->
        # We are assuming the error was already logged elsewhere.
        format_reply(state.serializer.encode!(error_reply_msg), state)
    end
  end

  def ws_info({:EXIT, socket_pid, reason}, state) do
    case HashDict.get(state.sockets_inverse, socket_pid) do
      nil   -> {:ok, state}
      topic ->
        new_state = delete(state, topic, socket_pid)

        case reason do
          :normal ->
            format_reply(state.serializer.encode!(Transport.chan_close_message(topic)), new_state)
          :shutdown ->
            format_reply(state.serializer.encode!(Transport.chan_close_message(topic)), new_state)
          {:shutdown, _} ->
            format_reply(state.serializer.encode!(Transport.chan_close_message(topic)), new_state)
          _other ->
            format_reply(state.serializer.encode!(Transport.chan_error_message(topic)), new_state)
        end
    end
  end

  @doc """
  Detects disconnect broadcasts and shuts down
  """
  def ws_info(%Broadcast{event: "disconnect"}, state) do
    {:shutdown, state}
  end

  def ws_info({:socket_push, :text, _encoded_payload} = msg, state) do
    format_reply(msg, state)
  end

  def ws_info(_, state) do
    {:ok, state}
  end

  def ws_terminate(_reason, _state) do
    :ok
  end

  def ws_close(state) do
    for {pid, _} <- state.sockets_inverse do
      Phoenix.Channel.Server.close(pid)
    end
  end

  defp put(state, topic, socket_pid) do
    %{state | sockets: HashDict.put(state.sockets, topic, socket_pid),
              sockets_inverse: HashDict.put(state.sockets_inverse, socket_pid, topic)}
  end

  defp delete(state, topic, socket_pid) do
    %{state | sockets: HashDict.delete(state.sockets, topic),
              sockets_inverse: HashDict.delete(state.sockets_inverse, socket_pid)}
  end

  defp format_reply({:socket_push, :text, encoded_payload}, state) do
    {:reply, {:text, encoded_payload}, state}
  end
end
