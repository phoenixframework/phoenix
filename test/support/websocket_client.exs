defmodule Phoenix.Integration.WebsocketClient do
  @moduledoc """
  A WebSocket client used to test Phoenix.Channel
  """

  use GenServer
  import Kernel, except: [send: 2]

  defstruct [
    :conn,
    :request_ref,
    :websocket,
    :caller,
    :status,
    :resp_headers,
    :sender,
    :serializer,
    closing?: false,
    topics: %{},
    # Use different initial join_ref from ref to
    # make sure the server is not coupling them.
    join_ref: 11,
    ref: 1
  ]

  alias Phoenix.Socket.Message

  @doc """
  Starts the WebSocket client for given ws URL. `Phoenix.Socket.Message`s
  received from the server are forwarded to the sender pid.
  """
  def connect(sender, url, serializer, headers \\ []) do
    with {:ok, socket} <- GenServer.start_link(__MODULE__, {sender, serializer}),
         {:ok, :connected} <- GenServer.call(socket, {:connect, url, headers}) do
      {:ok, socket}
    end
  end

  @doc """
  Closes the socket
  """
  def close(socket) do
    GenServer.cast(socket, :close)
  end

  @doc """
  Sends an event to the WebSocket server per the message protocol.
  """
  def send_event(socket, topic, event, msg) do
    GenServer.call(socket, {:send, %Message{topic: topic, event: event, payload: msg}})
  end

  @doc """
  Sends a low-level text message to the client.
  """
  def send(socket, msg) do
    GenServer.call(socket, {:send, msg})
  end

  @doc """
  Sends a heartbeat event
  """
  def send_heartbeat(socket) do
    send_event(socket, "phoenix", "heartbeat", %{})
  end

  @doc """
  Sends join event to the WebSocket server per the Message protocol
  """
  def join(socket, topic, msg) do
    send_event(socket, topic, "phx_join", msg)
  end

  @doc """
  Sends leave event to the WebSocket server per the Message protocol
  """
  def leave(socket, topic, msg) do
    send_event(socket, topic, "phx_leave", msg)
  end

  ## GenServer implementation

  @doc false
  def init({sender, serializer}) do
    state = %__MODULE__{sender: sender, serializer: serializer}

    {:ok, state}
  end

  @doc false
  def handle_call({:connect, url, headers}, from, state) do
    uri = URI.parse(url)

    http_scheme =
      case uri.scheme do
        "ws" -> :http
        "wss" -> :https
      end

    ws_scheme =
      case uri.scheme do
        "ws" -> :ws
        "wss" -> :wss
      end

    path =
      case uri.query do
        nil -> uri.path
        query -> uri.path <> "?" <> query
      end

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, headers) do
      state = %{state | conn: conn, request_ref: ref, caller: from}
      {:noreply, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(state.conn, conn)}
    end
  end

  def handle_call({:send, msg}, _from, state) do
    {frame, state} = serialize_msg(msg, state)

    case stream_frame(state, frame) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, state, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @doc false
  def handle_cast(:close, state) do
    do_close(state)
  end

  defp do_close(state) do
    # Streaming a close frame may fail if the server has already closed
    # for writing.
    _ = stream_frame(state, :close)
    Mint.HTTP.close(state.conn)
    {:stop, :normal, state}
  end

  @doc false
  def handle_info(message, state) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state = put_in(state.conn, conn) |> handle_responses(responses)
        if state.closing?, do: do_close(state), else: {:noreply, state}

      {:error, conn, reason, _responses} ->
        state = put_in(state.conn, conn) |> reply({:error, reason})
        {:noreply, state}

      :unknown ->
        {:noreply, state}
    end
  end

  defp handle_responses(state, responses)

  defp handle_responses(%{request_ref: ref} = state, [{:status, ref, status} | rest]) do
    put_in(state.status, status)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:headers, ref, resp_headers} | rest]) do
    put_in(state.resp_headers, resp_headers)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:done, ref} | rest]) do
    case Mint.WebSocket.new(state.conn, ref, state.status, state.resp_headers) do
      {:ok, conn, websocket} ->
        %{state | conn: conn, websocket: websocket, status: nil, resp_headers: nil}
        |> reply({:ok, :connected})
        |> handle_responses(rest)

      {:error, conn, reason} ->
        put_in(state.conn, conn)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(%{request_ref: ref, websocket: websocket} = state, [
         {:data, ref, data} | rest
       ])
       when websocket != nil do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        put_in(state.websocket, websocket)
        |> handle_frames(frames)
        |> handle_responses(rest)

      {:error, websocket, reason} ->
        put_in(state.websocket, websocket)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(state, [_response | rest]) do
    handle_responses(state, rest)
  end

  defp handle_responses(state, []), do: state

  defp handle_frames(state, frames) do
    {frames, state} =
      Enum.flat_map_reduce(frames, state, fn
        # reply to ping with pong
        {:ping, data} = frame, state ->
          {:ok, state} = stream_frame(state, {:pong, data})

          {[frame], state}

        # deserialize text and binary frames
        {:text, text}, state ->
          frame =
            case state.serializer do
              :noop -> {:text, text}
              serializer -> serializer.decode!(text, opcode: :text)
            end

          {[frame], state}

        {:binary, data}, state ->
          {[binary_decode(data)], state}

        # prepare to close the connection when a close frame is received
        {:close, _code, _data}, state ->
          {[], put_in(state.closing?, true)}

        frame, state ->
          {[frame], state}
      end)

    Enum.each(frames, &Kernel.send(state.sender, &1))

    state
  end

  # Encodes a frame as a binary and sends it along the wire, keeping `conn`
  # and `websocket` up to date in `state`.
  defp stream_frame(state, frame) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, frame),
         state = put_in(state.websocket, websocket),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, state.request_ref, data) do
      {:ok, put_in(state.conn, conn)}
    else
      {:error, %Mint.WebSocket{} = websocket, reason} ->
        {:error, put_in(state.websocket, websocket), reason}

      {:error, conn, reason} ->
        {:error, put_in(state.conn, conn), reason}
    end
  end

  # reply to an open GenServer call request if there is one
  defp reply(state, response) do
    if state.caller, do: GenServer.reply(state.caller, response)
    put_in(state.caller, nil)
  end

  defp serialize_msg(msg, %{serializer: :noop} = state), do: {msg, state}

  defp serialize_msg(%Message{payload: {:binary, _}} = msg, %{ref: ref} = state) do
    {join_ref, state} = join_ref_for(msg, state)
    msg = Map.merge(msg, %{ref: to_string(ref), join_ref: to_string(join_ref)})
    {{:binary, binary_encode_push!(msg)}, put_in(state.ref, ref + 1)}
  end

  defp serialize_msg(%Message{} = msg, %{ref: ref} = state) do
    {join_ref, state} = join_ref_for(msg, state)
    msg = Map.merge(msg, %{ref: to_string(ref), join_ref: to_string(join_ref)})
    {{:text, encode!(msg, state)}, put_in(state.ref, ref + 1)}
  end

  defp serialize_msg(msg, state), do: {msg, state}

  defp join_ref_for(
         %{topic: topic, event: "phx_join"},
         %{topics: topics, join_ref: join_ref} = state
       ) do
    topics = Map.put(topics, topic, join_ref)
    {join_ref, %{state | topics: topics, join_ref: join_ref + 1}}
  end

  defp join_ref_for(%{topic: topic}, %{topics: topics} = state) do
    {Map.get(topics, topic), state}
  end

  defp encode!(map, state) do
    {:socket_push, :text, chardata} = state.serializer.encode!(map)
    IO.chardata_to_string(chardata)
  end

  defp binary_encode_push!(%Message{payload: {:binary, data}} = msg) do
    ref = to_string(msg.ref)
    join_ref = to_string(msg.join_ref)
    join_ref_size = byte_size(join_ref)
    ref_size = byte_size(ref)
    topic_size = byte_size(msg.topic)
    event_size = byte_size(msg.event)

    <<
      0::size(8),
      join_ref_size::size(8),
      ref_size::size(8),
      topic_size::size(8),
      event_size::size(8),
      join_ref::binary-size(join_ref_size),
      ref::binary-size(ref_size),
      msg.topic::binary-size(topic_size),
      msg.event::binary-size(event_size),
      data::binary
    >>
  end

  # push
  defp binary_decode(<<
         0::size(8),
         join_ref_size::size(8),
         topic_size::size(8),
         event_size::size(8),
         join_ref::binary-size(join_ref_size),
         topic::binary-size(topic_size),
         event::binary-size(event_size),
         data::binary
       >>) do
    %Message{join_ref: join_ref, topic: topic, event: event, payload: {:binary, data}}
  end

  # reply
  defp binary_decode(<<
         1::size(8),
         join_ref_size::size(8),
         ref_size::size(8),
         topic_size::size(8),
         status_size::size(8),
         join_ref::binary-size(join_ref_size),
         ref::binary-size(ref_size),
         topic::binary-size(topic_size),
         status::binary-size(status_size),
         data::binary
       >>) do
    payload = %{"status" => status, "response" => {:binary, data}}
    %Message{join_ref: join_ref, ref: ref, topic: topic, event: "phx_reply", payload: payload}
  end
end
