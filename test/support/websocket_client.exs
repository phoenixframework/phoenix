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
    {:ok, %{sender: sender, join_ref: 1, ref: 0, serializer: serializer}}
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

  @doc false
  def websocket_info({:send, msg}, _conn_state, %{serializer: :noop} = state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info({:send, %Message{} = msg}, _conn_state, state) do
    msg = Map.merge(msg, %{ref: to_string(state.ref + 1), join_ref: to_string(state.join_ref)})
    {:reply, {:text, encode!(msg, state)}, put_in(state, [:ref], state.ref + 1)}
  end

  def websocket_info(:close, _conn_state, _state) do
    {:close, <<>>, "done"}
  end

  @doc false
  def websocket_terminate(_reason, _conn_state, _state) do
    :ok
  end

  defp encode!(map, state) do
    {:socket_push, :text, chardata} = state.serializer.encode!(map)
    IO.chardata_to_string(chardata)
  end
end
