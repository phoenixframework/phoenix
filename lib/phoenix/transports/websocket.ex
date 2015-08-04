defmodule Phoenix.Transports.WebSocket do
  @moduledoc """
  Socket transport for websocket clients.

  ## Configuration

  The websocket is configurable in your socket:

      transport :websocket, Phoenix.Transports.WebSocket,
        timeout: :infinity,
        serializer: Phoenix.Transports.WebSocketSerializer,
        log: false,
        check_origin: true

    * `:timeout` - the timeout for keeping websocket connections
      open after it last received data

    * `:log` - if the transport layer itself should log and, if so, the level

    * `:serializer` - the serializer for websocket messages

    * `:check_origin` - if we should check the origin of requests when the
      origin header is present. It defaults to true and, in such cases,
      it will check against the host value in `YourApp.Endpoint.config(:url)[:host]`.
      It may be set to `false` (not recommended) or to a list of explicitly
      allowed origins

  ## Serializer

  By default, JSON encoding is used to broker messages to and from clients.
  A custom serializer may be given as module which implements the `encode!/1`
  and `decode!/2` functions defined by the `Phoenix.Transports.Serializer`
  behaviour.

  The `encode!/1` function must return a tuple in the format
  `{:socket_push, :text | :binary, String.t | binary}`.
  """
  @behaviour Phoenix.Channel.Transport

  def default_config() do
    [serializer: Phoenix.Transports.WebSocketSerializer,
     timeout: :infinity,
     log: false,
     check_origin: true]
  end

  def handler_for(:cowboy), do: Phoenix.Endpoint.CowboyWebSocket

  ## Callbacks

  import Plug.Conn, only: [fetch_query_params: 1, send_resp: 3]

  alias Phoenix.Socket.Broadcast
  alias Phoenix.Channel.Transport

  @doc false
  def init(%Plug.Conn{method: "GET"} = conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)

    conn =
      conn
      |> Plug.Conn.fetch_query_params
      |> Transport.transport_log(opts[:log])
      |> Transport.force_ssl(handler, endpoint)
      |> Transport.check_origin(endpoint, opts[:check_origin])

    case conn do
      %{halted: false} = conn ->
        params     = conn.params
        serializer = Keyword.fetch!(opts, :serializer)

        case Transport.connect(endpoint, handler, transport, __MODULE__, serializer, params) do
          {:ok, socket} ->
            socket = %{socket | transport_pid: self()}
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

  @doc false
  def ws_init({socket, config}) do
    Process.flag(:trap_exit, true)
    serializer = Keyword.fetch!(config, :serializer)
    timeout    = Keyword.fetch!(config, :timeout)

    if socket.id, do: socket.endpoint.subscribe(self, socket.id, link: true)

    {:ok, %{socket: socket,
            channels: HashDict.new,
            channels_inverse: HashDict.new,
            serializer: serializer}, timeout}
  end

  @doc false
  def ws_handle(opcode, payload, state) do
    msg = state.serializer.decode!(payload, opcode: opcode)

    case Transport.dispatch(msg, state.channels, state.socket) do
      {:ok, channel_pid, reply_msg} ->
        format_reply(state.serializer.encode!(reply_msg), put(state, msg.topic, channel_pid))
      {:ok, reply_msg} ->
        format_reply(state.serializer.encode!(reply_msg), state)
      :ok ->
        {:ok, state}
      {:error, _reason, error_reply_msg} ->
        # We are assuming the error was already logged elsewhere.
        format_reply(state.serializer.encode!(error_reply_msg), state)
    end
  end

  @doc false
  def ws_info({:EXIT, channel_pid, reason}, state) do
    case HashDict.get(state.channels_inverse, channel_pid) do
      nil   -> {:ok, state}
      topic ->
        new_state = delete(state, topic, channel_pid)

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

  @doc false
  def ws_info(%Broadcast{event: "disconnect"}, state) do
    {:shutdown, state}
  end

  def ws_info({:socket_push, _, _encoded_payload} = msg, state) do
    format_reply(msg, state)
  end

  def ws_info(_, state) do
    {:ok, state}
  end

  @doc false
  def ws_terminate(_reason, _state) do
    :ok
  end

  @doc false
  def ws_close(state) do
    for {pid, _} <- state.channels_inverse do
      Phoenix.Channel.Server.close(pid)
    end
  end

  defp put(state, topic, channel_pid) do
    %{state | channels: HashDict.put(state.channels, topic, channel_pid),
              channels_inverse: HashDict.put(state.channels_inverse, channel_pid, topic)}
  end

  defp delete(state, topic, channel_pid) do
    %{state | channels: HashDict.delete(state.channels, topic),
              channels_inverse: HashDict.delete(state.channels_inverse, channel_pid)}
  end

  defp format_reply({:socket_push, encoding, encoded_payload}, state) do
    {:reply, {encoding, encoded_payload}, state}
  end
end
