defmodule Phoenix.Transports.WebSocket do
  @moduledoc """
  Socket transport for websocket clients.

  ## Configuration

  The websocket is configurable in your socket:

      transport :websocket, Phoenix.Transports.WebSocket,
        timeout: :infinity,
        serializer: [{Phoenix.Transports.WebSocketSerializer, "~> 2.0.0"}],
        transport_log: false

    * `:timeout` - the timeout for keeping websocket connections
      open after it last received data, defaults to 60_000ms

    * `:transport_log` - if the transport layer itself should log and, if so, the level

    * `:serializer` - the serializer for websocket messages

    * `:check_origin` - if we should check the origin of requests when the
      origin header is present. It defaults to true and, in such cases,
      it will check against the host value in `YourApp.Endpoint.config(:url)[:host]`.
      It may be set to `false` (not recommended) or to a list of explicitly
      allowed origins.

      check_origin: ["https://example.com",
                     "//another.com:888", "//other.com"]

      Note: To connect from a native app be sure to either have the native app
      set an origin or allow any origin via `check_origin: false`

    * `:code_reloader` - optionally override the default `:code_reloader` value
      from the socket's endpoint

  ## Serializer

  By default, JSON encoding is used to broker messages to and from clients.
  A custom serializer may be given as a module which implements the `encode!/1`
  and `decode!/2` functions defined by the `Phoenix.Transports.Serializer`
  behaviour.

  The `encode!/1` function must return a tuple in the format
  `{:socket_push, :text | :binary, String.t | binary}`.

  ## Garbage collection

  It's possible to force garbage collection in the transport process after
  processing large messages.

  Send `:garbage_collect` clause to the transport process:

      send socket.transport_pid, :garbage_collect
  """

  @behaviour Phoenix.Socket.Transport

  def default_config() do
    [serializer: [{Phoenix.Transports.WebSocketSerializer, "~> 1.0.0"},
                  {Phoenix.Transports.V2.WebSocketSerializer, "~> 2.0.0"}],
     timeout: 60_000,
     transport_log: false]
  end

  ## Callbacks

  import Plug.Conn, only: [fetch_query_params: 1, send_resp: 3]

  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Transport

  @doc false
  def init(%Plug.Conn{method: "GET"} = conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)

    conn =
      conn
      |> code_reload(opts, endpoint)
      |> fetch_query_params()
      |> Transport.transport_log(opts[:transport_log])
      |> Transport.force_ssl(handler, endpoint, opts)
      |> Transport.check_origin(handler, endpoint, opts)

    case conn do
      %{halted: false} = conn ->
        params     = conn.params
        serializer = Keyword.fetch!(opts, :serializer)

        case Transport.connect(endpoint, handler, transport, __MODULE__, serializer, params) do
          {:ok, socket} ->
            {:ok, conn, {__MODULE__, {socket, opts}}}
          :error ->
            conn = send_resp(conn, 403, "")
            {:error, conn}
        end
      %{halted: true} = conn ->
        {:error, conn}
    end
  end

  def init(conn, _) do
    conn = send_resp(conn, :bad_request, "")
    {:error, conn}
  end

  @doc false
  def ws_init({socket, config}) do
    Process.flag(:trap_exit, true)
    timeout = Keyword.fetch!(config, :timeout)

    if socket.id, do: socket.endpoint.subscribe(socket.id, link: true)

    {:ok, %{socket: socket,
            channels: %{},
            channels_inverse: %{},
            serializer: socket.serializer}, timeout}
  end

  @doc false
  def ws_handle(opcode, payload, state) do
    msg = state.serializer.decode!(payload, opcode: opcode)

    case Transport.dispatch(msg, state.channels, state.socket) do
      :noreply ->
        {:ok, state}
      {:reply, reply_msg} ->
        encode_reply(reply_msg, state)
      {:joined, channel_pid, reply_msg} ->
        encode_reply(reply_msg, put(state, msg.topic, msg.ref, channel_pid))
      {:error, _reason, error_reply_msg} ->
        encode_reply(error_reply_msg, state)
    end
  end

  @doc false
  def ws_info({:EXIT, channel_pid, reason}, state) do
    case Map.get(state.channels_inverse, channel_pid) do
      nil   -> {:ok, state}
      {topic, join_ref} ->
        new_state = delete(state, topic, channel_pid)
        encode_reply(Transport.on_exit_message(topic, join_ref, reason), new_state)
    end
  end

  def ws_info({:graceful_exit, channel_pid, %Phoenix.Socket.Message{} = msg}, state) do
    new_state = delete(state, msg.topic, channel_pid)
    encode_reply(msg, new_state)
  end

  @doc false
  def ws_info(%Broadcast{event: "disconnect"}, state) do
    {:shutdown, state}
  end

  def ws_info({:socket_push, _, _encoded_payload} = msg, state) do
    format_reply(msg, state)
  end

  @doc false
  def ws_info(:garbage_collect, state) do
    :erlang.garbage_collect(self())
    {:ok, state}
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

  defp put(state, topic, join_ref, channel_pid) do
    %{state | channels: Map.put(state.channels, topic, channel_pid),
              channels_inverse: Map.put(state.channels_inverse, channel_pid, {topic, join_ref})}
  end

  defp delete(state, topic, channel_pid) do
    case Map.fetch(state.channels, topic) do
      {:ok, ^channel_pid} ->
        %{state | channels: Map.delete(state.channels, topic),
                  channels_inverse: Map.delete(state.channels_inverse, channel_pid)}
      {:ok, _newer_pid} ->
        %{state | channels_inverse: Map.delete(state.channels_inverse, channel_pid)}
    end
  end

  defp encode_reply(reply, state) do
    format_reply(state.serializer.encode!(reply), state)
  end

  defp format_reply({:socket_push, encoding, encoded_payload}, state) do
    {:reply, {encoding, encoded_payload}, state}
  end

  defp code_reload(conn, opts, endpoint) do
    reload? = Keyword.get(opts, :code_reloader, endpoint.config(:code_reloader))
    if reload?, do: Phoenix.CodeReloader.reload!(endpoint)

    conn
  end
end
