defmodule Phoenix.Transports.LongPoll.Server do
  @moduledoc false

  use GenServer, restart: :temporary
  alias Phoenix.PubSub
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init({endpoint, handler, options, params, priv_topic, connect_info}) do
    config = %{
      endpoint: endpoint,
      transport: :longpoll,
      options: options,
      params: params,
      connect_info: connect_info
    }

    window_ms = Keyword.fetch!(options, :window_ms)

    case handler.connect(config) do
      {:ok, handler_state} ->
        {:ok, handler_state} = handler.init(handler_state)

        state = %{
          # The messages the client did not acknowledge yet, as {seq, payload}.
          # We number them starting at 1 and send all of them with each poll,
          # together with the number of the last one, until the client acknowledges
          # them, as the response of a poll can get lost.
          out: :queue.new(),
          # the number of the last message we numbered, sent and the client acknowledged
          out_seq: 0,
          sent: 0,
          acked: 0,
          # when the client last acknowledged new messages or had none left to acknowledge,
          # see expired?/1
          acked_at: now_ms(),
          # the number of the last message we received, to drop the ones the client resends
          in_seq: 0,
          handler: {handler, handler_state},
          window_ms: trunc(window_ms * 1.5),
          pubsub_server: endpoint.config(:pubsub_server),
          priv_topic: priv_topic,
          client_ref: nil
        }

        :ok = PubSub.subscribe(state.pubsub_server, priv_topic)
        schedule_inactive_shutdown(state.window_ms)
        {:ok, state}

      :error ->
        :ignore

      {:error, _reason} ->
        :ignore
    end
  end

  # The client numbers its messages and sends them again when it did not get the
  # response to its POST, so we drop the ones we already received.
  def handle_info({:dispatch, client_ref, _body, ref, seq}, %{in_seq: in_seq} = state)
      when seq <= in_seq do
    broadcast_from!(state, client_ref, {:ok, ref})
    {:noreply, state}
  end

  # We cannot process the message, as we lost the ones before it.
  def handle_info({:dispatch, client_ref, _body, ref, seq}, %{in_seq: in_seq} = state)
      when seq > in_seq + 1 do
    broadcast_from!(state, client_ref, {:error, ref})
    {:stop, {:shutdown, :out_of_order}, state}
  end

  def handle_info({:dispatch, client_ref, {body, opcode}, ref, _seq}, state) do
    %{handler: {handler, handler_state}} = state
    state = %{state | in_seq: state.in_seq + 1}

    case handler.handle_in({body, opcode: opcode}, handler_state) do
      {:reply, status, {reply_opcode, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        status = if status == :ok, do: :ok, else: :error
        broadcast_from!(state, client_ref, {status, ref})
        publish_reply(state, reply_opcode, reply)

      {:ok, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        broadcast_from!(state, client_ref, {:ok, ref})
        {:noreply, state}

      {:stop, reason, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        broadcast_from!(state, client_ref, {:error, ref})
        {:stop, reason, state}
    end
  end

  def handle_info({:subscribe, client_ref, ref}, state) do
    broadcast_from!(state, client_ref, {:subscribe, ref})
    {:noreply, state}
  end

  # The client acknowledges the last message it received with each poll, so we send
  # the messages after it until it did, as the response of a poll can get lost.
  def handle_info({:flush, client_ref, ref, ack}, state) do
    state = acknowledge(state, ack)

    if :queue.is_empty(state.out) do
      {:noreply, %{state | client_ref: {client_ref, ref}}}
    else
      broadcast_from!(state, client_ref, {:messages, payloads(state), ref, state.out_seq})
      {:noreply, %{state | sent: state.out_seq, client_ref: nil}}
    end
  end

  # Nodes before Phoenix v1.8.18 forward requests without the numbers of the messages,
  # as do newer nodes for older clients. We cannot serve them, as we would send our
  # messages again and again, so we stop and the client starts a new session.
  def handle_info({:flush, _client_ref, _ref}, state), do: stop_unnumbered(state)
  def handle_info({:dispatch, _client_ref, _body, _ref}, state), do: stop_unnumbered(state)

  def handle_info({:expired, client_ref, ref}, state) do
    case state.client_ref do
      {^client_ref, ^ref} ->
        {:noreply, %{state | client_ref: nil}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:shutdown_if_inactive, state) do
    if expired?(state) do
      stop_expired(state)
    else
      schedule_inactive_shutdown(state.window_ms)
      {:noreply, state}
    end
  end

  def handle_info(message, state) do
    %{handler: {handler, handler_state}} = state

    case handler.handle_info(message, handler_state) do
      {:push, {opcode, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        publish_reply(state, opcode, reply)

      {:ok, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        {:noreply, state}

      {:stop, reason, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        {:stop, reason, state}
    end
  end

  def terminate(reason, state) do
    %{handler: {handler, handler_state}} = state
    handler.terminate(reason, handler_state)
    :ok
  end

  defp broadcast_from!(state, client_ref, msg) when is_binary(client_ref),
    do: PubSub.broadcast_from!(state.pubsub_server, self(), client_ref, msg)

  defp broadcast_from!(_state, client_ref, msg) when is_pid(client_ref),
    do: send(client_ref, msg)

  defp publish_reply(state, _opcode, reply) when is_map(reply) do
    IO.warn(
      "Returning a map from the LongPolling serializer is deprecated. " <>
        "Please return JSON encoded data instead (see Phoenix.Socket.Serializer)"
    )

    publish_reply(state, :text, Phoenix.json_library().encode_to_iodata!(reply))
  end

  # The poll response is a JSON document, which cannot hold arbitrary bytes.
  # Binary frames are sent base64-encoded in an object, so clients can tell
  # them apart from text frames, which are sent as strings.
  defp publish_reply(state, :binary, reply) do
    buffer_reply(state, %{"binary" => Base.encode64(IO.iodata_to_binary(reply))})
  end

  defp publish_reply(state, _opcode, reply) do
    buffer_reply(state, IO.iodata_to_binary(reply))
  end

  defp buffer_reply(state, reply) do
    # A client that does not acknowledge must not be able to
    # grow the buffer indefinitely, so we close when it did not acknowledge
    # the messages we sent within the window.
    if expired?(state) do
      stop_expired(state)
    else
      notify_client_now_available(state)
      seq = state.out_seq + 1
      {:noreply, %{state | out: :queue.in({seq, reply}, state.out), out_seq: seq}}
    end
  end

  defp payloads(state) do
    for {_seq, payload} <- :queue.to_list(state.out), do: payload
  end

  # Drops the messages up to the acknowledged one. A late poll can acknowledge
  # an older message, and a client cannot acknowledge messages we did not send.
  defp acknowledge(state, ack) do
    acked = ack |> min(state.sent) |> max(state.acked)

    # while the client makes progress, the rest of the messages get a new window
    if acked > state.acked or acked == state.sent do
      %{state | out: drop_until(state.out, acked), acked: acked, acked_at: now_ms()}
    else
      state
    end
  end

  defp drop_until(queue, ack) do
    case :queue.peek(queue) do
      {:value, {seq, _payload}} when seq <= ack -> drop_until(:queue.drop(queue), ack)
      _ -> queue
    end
  end

  # The client acknowledges the messages it received with each poll. When it did not
  # acknowledge new messages within the window, and it has messages left to acknowledge,
  # it does not get our responses. When it has none, it stopped polling.
  defp expired?(state), do: now_ms() - state.acked_at > state.window_ms

  defp stop_expired(%{acked: acked, sent: sent} = state) when acked < sent,
    do: {:stop, {:shutdown, :unacknowledged}, state}

  defp stop_expired(state),
    do: {:stop, {:shutdown, :inactive}, state}

  defp stop_unnumbered(state) do
    Logger.error(
      "Phoenix.Transports.LongPoll.Server received a long-poll request without message " <>
        "numbers, which nodes and clients before Phoenix v1.8.18 send, and stops the session. " <>
        "If you do rolling deploys, deploy Phoenix v1.8.18 or a later v1.8 release first. " <>
        "Browsers that still run an older phoenix.js client must reload the page"
    )

    {:stop, {:shutdown, :unnumbered}, state}
  end

  defp notify_client_now_available(state) do
    case state.client_ref do
      {client_ref, ref} -> broadcast_from!(state, client_ref, {:now_available, ref})
      nil -> :ok
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp schedule_inactive_shutdown(window_ms) do
    Process.send_after(self(), :shutdown_if_inactive, window_ms)
  end
end
