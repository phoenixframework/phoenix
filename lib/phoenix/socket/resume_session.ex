defmodule Phoenix.Socket.ResumeSession do
  @moduledoc false
  # The session of a resumable socket.
  #
  # It is the stable `transport_pid` of every resumable channel on a socket, while
  # the transport process of the current connection (the "pipe") changes when the
  # client reconnects. All frames of resumable channels go through it, so it can
  # keep the frames the client has not acknowledged yet and replay them on resume.
  #
  # Resumable channels encode their frames with a serializer that wraps them with
  # their topic and join_ref, see `serializer/1`, so the session numbers the frames
  # of each channel join. The client counts the frames it received for each join
  # after its phx_resumable marker, and acknowledges and resumes with these counts.
  #
  # A connection that does not keep resumable channels itself, such as long polling,
  # which is resumable by construction, can resume the session as well. The session
  # then releases the channels to that connection: it replays the missed frames,
  # hands the channels over to it and stops once all of them confirmed the handover.
  #
  # Inbound frames do not go through the session. Resumable channels drop messages
  # with refs they have already seen, which covers frames the client resends after
  # a resume as well as late frames of a half-open connection.
  use GenServer, restart: :temporary

  require Logger

  alias Phoenix.Socket.{Broadcast, Message}

  @salt "phoenix socket resume"

  defmodule V2JSONSerializer do
    @moduledoc false
    @behaviour Phoenix.Socket.Serializer

    alias Phoenix.Socket.V2.JSONSerializer

    @impl true
    def fastlane!(broadcast), do: JSONSerializer.fastlane!(broadcast)

    @impl true
    def encode!(%{topic: topic, join_ref: join_ref} = message) do
      {:socket_push, opcode, payload} = JSONSerializer.encode!(message)
      {:socket_resumable_push, topic, join_ref, {opcode, payload}}
    end

    @impl true
    def decode!(raw_message, opts), do: JSONSerializer.decode!(raw_message, opts)
  end

  @doc """
  Returns the serializer resumable channels use to send frames to the session,
  or nil if the given serializer does not support resuming.
  """
  def serializer(Phoenix.Socket.V2.JSONSerializer), do: V2JSONSerializer
  def serializer(_serializer), do: nil

  def child_spec({_socket, _opts} = arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}, restart: :temporary}
  end

  def start_link(arg), do: GenServer.start_link(__MODULE__, arg)

  @doc """
  Starts a session for the socket of the calling transport process.
  """
  def start(socket, opts) do
    key = {socket.id, self()}
    child_spec = child_spec({socket, Keyword.put(opts, :pipe, self())})

    case Phoenix.Socket.PoolSupervisor.start_child(socket, key, child_spec) do
      {:ok, pid} -> {:ok, pid, GenServer.call(pid, :token)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Verifies a resume token and returns the session pid and its nonce.
  """
  def verify_token(endpoint, token) do
    # the token is only valid as long as its session is alive, which we can only
    # reach on our own node or a node we are connected to
    with {:ok, {pid, nonce}} <- Phoenix.Token.verify(endpoint, @salt, token, max_age: :infinity),
         true <- is_pid(pid) and (node(pid) == node() or node(pid) in Node.list()) do
      {:ok, pid, nonce}
    else
      _ -> :error
    end
  end

  ## Callbacks

  @impl true
  def init({socket, opts}) do
    pipe = Keyword.fetch!(opts, :pipe)
    nonce = :crypto.strong_rand_bytes(16)
    _ = socket.id && socket.endpoint.subscribe(socket.id)

    # TODO: replace with Process.put_label/2 when we require Elixir 1.17
    Process.put(:"$process_label", {__MODULE__, socket.handler, socket.id})

    state = %{
      handler: socket.handler,
      id: socket.id,
      serializer: socket.serializer,
      nonce: nonce,
      token: Phoenix.Token.sign(socket.endpoint, @salt, {self(), nonce}),
      timeout: Keyword.get(opts, :timeout, 20_000),
      pipe: nil,
      pipe_ref: nil,
      # %{topic => channel}, with the frames the client has not acknowledged yet. A channel
      # that stopped (pid nil) is kept until the client received its last frames.
      channels: %{},
      pids: %{},
      # orders the frames of all channels, to replay them in the order we sent them
      order: 0,
      park_timer: nil,
      # set while we release the channels to a connection that keeps them itself
      releasing: false,
      ack_check: nil
    }

    {:ok, attach(state, pipe)}
  end

  @impl true
  def handle_call(:token, _from, state) do
    {:reply, state.token, state}
  end

  @impl true
  def handle_info({:socket_resumable_push, topic, join_ref, frame}, state) do
    case state.channels do
      %{^topic => %{join_ref: ^join_ref}} -> {:noreply, push(state, topic, frame)}
      # a late frame of a previous join, the client would ignore it
      %{} -> {:noreply, state}
    end
  end

  def handle_info({:socket_push, _opcode, _payload}, state) do
    # without the resumable serializer we don't know whose frame it is, and the client
    # would not count it like we do, so we cannot send it
    Logger.warning("Dropping frame sent to resume session #{inspect(self())} without topic")
    {:noreply, state}
  end

  def handle_info({:socket_adopt, pid, topic, join_ref}, state) do
    state = drop_channel(state, topic)

    channel = %{
      join_ref: join_ref,
      pid: pid,
      ref: Process.monitor(pid),
      seq: 0,
      # the seq at the last ack check, which the client must have acknowledged by the next one
      checkpoint: 0,
      buffer: :queue.new()
    }

    {:noreply,
     %{
       state
       | channels: Map.put(state.channels, topic, channel),
         pids: Map.put(state.pids, pid, topic)
     }}
  end

  def handle_info({:socket_close, pid, _reason}, state) do
    case state.pids do
      %{^pid => topic} ->
        %{join_ref: join_ref, ref: ref} = state.channels[topic]
        Process.demonitor(ref, [:flush])

        state
        |> push(topic, encode(state, "phx_close", topic, join_ref))
        |> channel_stopped(topic)
        |> maybe_stop()

      %{} ->
        {:noreply, state}
    end
  end

  def handle_info({:socket_ack, acks}, state) do
    state =
      Enum.reduce(acks, state, fn {topic, join_ref, received}, state ->
        ack(state, topic, join_ref, received)
      end)

    # stopped channels the client does not count anymore already got their last frame
    listed = MapSet.new(acks, fn {topic, join_ref, _} -> {topic, join_ref} end)

    stale =
      for {topic, %{pid: nil, join_ref: join_ref}} <- state.channels,
          not MapSet.member?(listed, {topic, join_ref}),
          do: topic

    {:noreply, Enum.reduce(stale, state, &drop_channel(&2, &1))}
  end

  def handle_info({:socket_resume, from, ref, request}, state) do
    case resume(state, request) do
      {:ok, state} when request.release ->
        release(state, from, ref)

      {:ok, state} ->
        reattach(state, from, ref)

      {:error, reason} ->
        send(from, {:socket_resumed, ref, {:error, reason}})
        {:noreply, state}
    end
  end

  # The last frame a released channel sends us, its frames after it go to the new connection.
  def handle_info({:socket_handed_over, pid}, %{releasing: true} = state) do
    case Map.pop(state.pids, pid) do
      {nil, _} ->
        {:noreply, state}

      {topic, pids} ->
        {ch, channels} = Map.pop(state.channels, topic)
        Process.demonitor(ch.ref, [:flush])
        notify_pipe(state, {:socket_session_released, topic, :handed_over})
        maybe_stop(%{state | channels: channels, pids: pids})
    end
  end

  # the channels that are not released yet cannot be resumed without the frames we
  # passed on, so they stop with us
  def handle_info(
        {:DOWN, ref, _, pipe, _reason},
        %{pipe: pipe, pipe_ref: ref, releasing: true} = state
      ) do
    {:stop, {:shutdown, :closed}, state}
  end

  def handle_info({:DOWN, ref, _, pipe, _reason}, %{pipe: pipe, pipe_ref: ref} = state) do
    state = cancel_ack_check(state)
    timer = Process.send_after(self(), :park_timeout, state.timeout)
    maybe_stop(%{state | pipe: nil, pipe_ref: nil, park_timer: timer})
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    case state.pids do
      %{^pid => topic} ->
        %{join_ref: join_ref} = state.channels[topic]

        message = %Message{
          join_ref: join_ref,
          ref: join_ref,
          topic: topic,
          event: "phx_error",
          payload: %{reason: "channel_crash"}
        }

        state
        |> push(topic, encode(state, message))
        |> channel_stopped(topic)
        |> maybe_stop()

      %{} ->
        {:noreply, state}
    end
  end

  def handle_info(:park_timeout, state) do
    {:stop, {:shutdown, :resume_timeout}, state}
  end

  # A client that stays connected without acknowledging must not let the buffers grow
  # indefinitely, so the frames sent before the last check must be acknowledged by now.
  # This keeps a frame for at most two timeouts without tracking when each one was sent.
  def handle_info({:ack_check, ref}, %{ack_check: {ref, _timer}} = state) do
    if Enum.any?(state.channels, fn {_topic, ch} -> unacknowledged?(ch) end) do
      Logger.debug("Client of socket #{inspect(state.id)} did not acknowledge its frames")
      {:stop, {:shutdown, :unacknowledged}, state}
    else
      {:noreply, checkpoint(state)}
    end
  end

  # a check that was canceled after its message was already sent
  def handle_info({:ack_check, _ref}, state) do
    {:noreply, state}
  end

  def handle_info(%Broadcast{event: "disconnect"}, state) do
    {:stop, {:shutdown, :disconnected}, state}
  end

  def handle_info(%Broadcast{event: "phx_drain"}, state) do
    {:stop, {:shutdown, :draining}, state}
  end

  def handle_info(:socket_drain, state) do
    notify_pipe(state, :socket_drain)
    {:stop, {:shutdown, :draining}, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  ## Helpers

  defp attach(state, pipe) do
    if state.park_timer, do: Process.cancel_timer(state.park_timer)
    state = cancel_ack_check(state)
    # the client can only acknowledge while connected, so the frames get a full timeout again
    checkpoint(%{state | pipe: pipe, pipe_ref: Process.monitor(pipe), park_timer: nil})
  end

  defp checkpoint(state) do
    channels = Map.new(state.channels, fn {topic, ch} -> {topic, %{ch | checkpoint: ch.seq}} end)
    ref = make_ref()
    timer = Process.send_after(self(), {:ack_check, ref}, state.timeout)
    %{state | channels: channels, ack_check: {ref, timer}}
  end

  defp cancel_ack_check(%{ack_check: nil} = state), do: state

  defp cancel_ack_check(%{ack_check: {_ref, timer}} = state) do
    Process.cancel_timer(timer)
    %{state | ack_check: nil}
  end

  defp unacknowledged?(ch) do
    case :queue.peek(ch.buffer) do
      {:value, {seq, _order, _frame}} -> seq <= ch.checkpoint
      :empty -> false
    end
  end

  defp push(%{releasing: true} = state, topic, frame) do
    notify_pipe(state, {:socket_session_push, topic, frame})
    state
  end

  defp push(state, topic, frame) do
    notify_pipe(state, {:socket_session_push, topic, frame})

    state =
      update_in(state.channels[topic], fn ch ->
        seq = ch.seq + 1
        %{ch | seq: seq, buffer: :queue.in({seq, state.order, frame}, ch.buffer)}
      end)

    %{state | order: state.order + 1}
  end

  defp ack(state, topic, join_ref, received) do
    case state.channels do
      %{^topic => %{join_ref: ^join_ref} = ch} ->
        buffer = drop_until(ch.buffer, received)

        if ch.pid == nil and :queue.is_empty(buffer) do
          %{state | channels: Map.delete(state.channels, topic)}
        else
          put_in(state.channels[topic].buffer, buffer)
        end

      %{} ->
        state
    end
  end

  defp drop_until(buffer, received) do
    case :queue.peek(buffer) do
      {:value, {seq, _, _}} when seq <= received -> drop_until(:queue.drop(buffer), received)
      _ -> buffer
    end
  end

  defp channel_stopped(%{releasing: true} = state, topic) do
    {%{pid: pid}, channels} = Map.pop(state.channels, topic)
    notify_pipe(state, {:socket_session_released, topic, :stopped})
    %{state | channels: channels, pids: Map.delete(state.pids, pid)}
  end

  defp channel_stopped(state, topic) do
    {%{pid: pid} = ch, channels} = Map.pop(state.channels, topic)
    notify_pipe(state, {:socket_session_closed, pid})
    state = %{state | pids: Map.delete(state.pids, pid)}

    # the frames of a channel that stopped, such as a redirect followed by its
    # phx_close, are still delivered if the client resumes before the timeout
    %{state | channels: Map.put(channels, topic, %{ch | pid: nil, ref: nil})}
  end

  defp drop_channel(state, topic) do
    case Map.pop(state.channels, topic) do
      {nil, _} ->
        state

      {ch, channels} ->
        if ch.ref, do: Process.demonitor(ch.ref, [:flush])

        %{state | channels: channels, pids: Map.delete(state.pids, ch.pid)}
    end
  end

  defp resume(state, request) do
    %{nonce: nonce, handler: handler, id: id, channels: claimed} = request

    cond do
      not Plug.Crypto.secure_compare(nonce, state.nonce) ->
        {:error, "invalid_token"}

      handler != state.handler or id != state.id ->
        {:error, "socket_changed"}

      true ->
        # the client resumed before we noticed that the previous connection is gone
        if state.pipe do
          Process.demonitor(state.pipe_ref, [:flush])
          send(state.pipe, {:socket_detach, self()})
        end

        state = %{state | pipe: nil, pipe_ref: nil}

        claimed =
          Map.new(claimed, fn {topic, join_ref, received} -> {topic, {join_ref, received}} end)

        state =
          Enum.reduce(state.channels, state, fn {topic, ch}, state ->
            case claimed do
              %{^topic => {join_ref, received}} when join_ref == ch.join_ref ->
                ack(state, topic, join_ref, received)

              # channels the client does not know as resumable, for example because the
              # connection dropped before it received their marker, rejoin instead
              %{} ->
                if ch.pid, do: Process.exit(ch.pid, {:shutdown, :closed})
                drop_channel(state, topic)
            end
          end)

        {:ok, state}
    end
  end

  defp maybe_stop(%{releasing: true, channels: channels} = state) when map_size(channels) == 0 do
    {:stop, {:shutdown, :released}, state}
  end

  defp maybe_stop(%{pipe: nil, channels: channels} = state) when map_size(channels) == 0 do
    {:stop, {:shutdown, :closed}, state}
  end

  defp maybe_stop(state), do: {:noreply, state}

  defp reattach(state, pipe, ref) do
    state = attach(state, pipe)
    channels = for {topic, ch} <- state.channels, do: {topic, ch.join_ref, ch.pid}
    send(pipe, {:socket_resumed, ref, {:ok, channels}})
    replay(state, pipe)
    {:noreply, state}
  end

  defp release(state, pipe, ref) do
    state = %{attach(state, pipe) | releasing: true} |> cancel_ack_check()
    channels = for {topic, ch} <- state.channels, do: {topic, ch.join_ref, ch.pid}
    send(pipe, {:socket_resumed, ref, {:ok, channels}})
    replay(state, pipe)

    # the channels send their frames to the new connection once handed over,
    # and stopped channels are done once their last frames are replayed
    channels =
      for {topic, ch} <- state.channels, ch.pid != nil, into: %{} do
        send(ch.pid, {:socket_handover, pipe, serializer(state.serializer)})
        {topic, %{ch | buffer: :queue.new()}}
      end

    maybe_stop(%{state | channels: channels})
  end

  defp replay(state, pipe) do
    state.channels
    |> Enum.flat_map(fn {topic, ch} ->
      for {_seq, order, frame} <- :queue.to_list(ch.buffer), do: {order, topic, frame}
    end)
    |> Enum.sort()
    |> Enum.each(fn {_order, topic, frame} ->
      send(pipe, {:socket_session_push, topic, frame})
    end)
  end

  defp notify_pipe(%{pipe: nil}, _message), do: :ok
  defp notify_pipe(%{pipe: pipe}, message), do: send(pipe, message)

  defp encode(state, event, topic, join_ref) do
    encode(state, %Message{
      join_ref: join_ref,
      ref: join_ref,
      topic: topic,
      event: event,
      payload: %{}
    })
  end

  defp encode(%{serializer: serializer}, message) do
    {:socket_push, opcode, payload} = serializer.encode!(message)
    {opcode, payload}
  end
end
