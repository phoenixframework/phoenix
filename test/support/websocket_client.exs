defmodule Phoenix.Integration.WebsocketClient do
  alias Phoenix.Socket.Message

  @doc """
  Starts the WebSocket server for given ws URL. Received Socket.Message's
  are forwarded to the sender pid
  """
  def start_link(sender, url, serializer, headers \\ []) do
    :crypto.start()
    :ssl.start()

    :websocket_client.start_link(
      String.to_charlist(url),
      __MODULE__,
      [sender, serializer],
      extra_headers: headers
    )
  end

  @doc """
  Closes the socket
  """
  def close(socket) do
    send(socket, :close)
  end

  @doc """
  Sends an event to the WebSocket server per the message protocol.
  """
  def send_event(server_pid, topic, event, msg) do
    send(server_pid, {:send, %Message{topic: topic, event: event, payload: msg}})
  end

  @doc """
  Sends a low-level text message to the client.
  """
  def send_message(server_pid, msg) do
    send(server_pid, {:send, msg})
  end

  @doc """
  Sends a control frame to the client.
  """
  def send_control_frame(server_pid, opcode, msg \\ :none) do
    send(server_pid, {:control, opcode, msg})
  end

  @doc """
  Sends a heartbeat event
  """
  def send_heartbeat(server_pid) do
    send_event(server_pid, "phoenix", "heartbeat", %{})
  end

  @doc """
  Sends join event to the WebSocket server per the Message protocol
  """
  def join(server_pid, topic, msg) do
    send_event(server_pid, topic, "phx_join", msg)
  end

  @doc """
  Sends leave event to the WebSocket server per the Message protocol
  """
  def leave(server_pid, topic, msg) do
    send_event(server_pid, topic, "phx_leave", msg)
  end

  @doc false
  def init([sender, serializer], _conn_state) do
    # Use different initial join_ref from ref to
    # make sure the server is not coupling them.
    {:ok, %{sender: sender, topics: %{}, join_ref: 11, ref: 1, serializer: serializer}}
  end

  @doc false
  def websocket_handle({:text, msg}, _conn_state, %{serializer: :noop} = state) do
    send(state.sender, {:text, msg})
    {:ok, state}
  end

  def websocket_handle({:text, msg}, _conn_state, state) do
    send(state.sender, state.serializer.decode!(msg, opcode: :text))
    {:ok, state}
  end

  def websocket_handle({:binary, data}, _conn_state, state) do
    send(state.sender, binary_decode(data))
    {:ok, state}
  end

  # The websocket client always sends a payload, even when none is explicitly set
  # on the frame.
  def websocket_handle({opcode, msg}, _conn_state, state) when opcode in [:ping, :pong] do
    send(state.sender, {:control, opcode, msg})
    {:ok, state}
  end

  @doc false
  def websocket_info({:send, msg}, _conn_state, %{serializer: :noop} = state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info({:control, opcode, msg}, _conn_state, %{serializer: :noop} = state) do
    case msg do
      :none -> {:reply, opcode, state}
      _ -> {:reply, {opcode, msg}, state}
    end
  end

  def websocket_info({:send, %Message{payload: {:binary, _}} = msg}, _conn_state, %{ref: ref} = state) do
    {join_ref, state} = join_ref_for(msg, state)
    msg = Map.merge(msg, %{ref: to_string(ref), join_ref: to_string(join_ref)})
    {:reply, {:binary, binary_encode_push!(msg)}, put_in(state.ref, ref + 1)}
  end

  def websocket_info({:send, %Message{} = msg}, _conn_state, %{ref: ref} = state) do
    {join_ref, state} = join_ref_for(msg, state)
    msg = Map.merge(msg, %{ref: to_string(ref), join_ref: to_string(join_ref)})
    {:reply, {:text, encode!(msg, state)}, put_in(state.ref, ref + 1)}
  end

  def websocket_info(:close, _conn_state, _state) do
    {:close, <<>>, "done"}
  end

  defp join_ref_for(%{topic: topic, event: "phx_join"}, %{topics: topics, join_ref: join_ref} = state) do
    topics = Map.put(topics, topic, join_ref)
    {join_ref, %{state | topics: topics, join_ref: join_ref + 1}}
  end

  defp join_ref_for(%{topic: topic}, %{topics: topics} = state) do
    {Map.get(topics, topic), state}
  end

  @doc false
  def websocket_terminate(_reason, _conn_state, _state) do
    :ok
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
