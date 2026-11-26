defmodule Phoenix.Transports.Session do
  @moduledoc false
  #
  # A socket session that outlives the requests of its transport.
  #
  # The session runs the socket handler, so it is the `transport_pid` of the socket
  # and its channels. Long polling talks to it through the processes of its requests,
  # so a client can retry a failed request without losing its socket.
  #
  #   LongPoll client
  #     GET  <--> request process :flush ----+
  #                                          +--> Session <--> socket handler
  #     POST <--> request process :dispatch -+
  #
  # Both directions number their messages, starting at 1:
  #
  #   * The session numbers the messages it sends and keeps them until the client
  #     acknowledges them with the number of the last message it received. It sends
  #     all messages after the acknowledged one again, together with the number of
  #     the last one, so the client can drop the ones it already received.
  #
  #   * The client numbers the messages it sends. The session drops the ones it
  #     already received, as the client sends them again when it did not get our
  #     response. Messages must arrive in order, as a gap means we lost messages.
  #
  # The numbers do not depend on how the transport groups messages.
  #
  # Long polling addresses the session with a `client_ref`, which is the pid of the
  # request process when it runs on a node we are connected to, or the PubSub
  # topic it subscribed to otherwise.

  use GenServer, restart: :temporary
  alias Phoenix.PubSub
  require Logger

  @doc """
  Returns a new private topic, which the session subscribes to.
  """
  def priv_topic do
    "phx:lp:" <>
      Base.encode64(:crypto.strong_rand_bytes(16)) <>
      (System.system_time(:millisecond) |> Integer.to_string())
  end

  @doc """
  Signs the token that clients use to reach the session.
  """
  def sign_token(endpoint, data, opts) do
    Phoenix.Token.sign(
      endpoint,
      Atom.to_string(endpoint.config(:pubsub_server)),
      data,
      opts[:crypto]
    )
  end

  @doc """
  Verifies a token signed with `sign_token/3`.
  """
  def verify_token(endpoint, signed, opts) do
    Phoenix.Token.verify(
      endpoint,
      Atom.to_string(endpoint.config(:pubsub_server)),
      signed,
      opts[:crypto]
    )
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  # Long polling connects the socket in the session. Sockets that long poll have always
  # run connect/1 and init/1 in the same process, so a connect/1 that depends on self(),
  # the process dictionary or Logger metadata keeps working.
  def init({endpoint, handler, options, params, priv_topic, connect_info}) do
    config = %{
      endpoint: endpoint,
      transport: :longpoll,
      options: options,
      params: params,
      connect_info: connect_info
    }

    case handler.connect(config) do
      {:ok, handler_state} ->
        {:ok, handler_state} = handler.init(handler_state)
        {:ok, init_state(endpoint, handler, handler_state, options, priv_topic)}

      :error ->
        :ignore

      {:error, _reason} ->
        :ignore
    end
  end

  defp init_state(endpoint, handler, handler_state, options, priv_topic) do
    state = %{
      handler: {handler, handler_state},
      # the messages the client did not acknowledge yet, as {seq, opcode, payload}
      out: :queue.new(),
      # the number of the last message we numbered, sent and the client acknowledged
      out_seq: 0,
      sent: 0,
      acked: 0,
      # when the client last acknowledged new messages or had none left to acknowledge,
      # see expired?/1
      acked_at: now_ms(),
      # the number of the last message we received
      in_seq: 0,
      window_ms: trunc(Keyword.fetch!(options, :window_ms) * 1.5),
      pubsub_server: endpoint.config(:pubsub_server),
      priv_topic: priv_topic,
      # how we reach the client: nil, or a request waiting for messages
      # as {:poll, client_ref, ref}
      client: nil
    }

    :ok = PubSub.subscribe(state.pubsub_server, priv_topic)
    schedule_inactive_shutdown(state.window_ms)
    state
  end

  ## Incoming messages

  def handle_info({:dispatch, client_ref, body, ref, seq}, state) do
    receive_in({:poll, client_ref, ref}, seq, body, state)
  end

  # Nodes before Phoenix v1.8.18 forward requests without the numbers of the messages,
  # as do newer nodes for older clients. We cannot serve them, as we would send our
  # messages again and again, so we stop and the client starts a new session.
  def handle_info({:dispatch, _client_ref, _body, _ref}, state), do: stop_unnumbered(state)
  def handle_info({:flush, _client_ref, _ref}, state), do: stop_unnumbered(state)

  # Answers a request that checks if the session is reachable.
  def handle_info({:subscribe, client_ref, ref}, state) do
    send_client(state, client_ref, {:subscribe, ref})
    {:noreply, state}
  end

  ## Outgoing messages

  # The client acknowledges the last message it received with each poll, so we send
  # the messages after it until it did, as the response of a poll can get lost.
  def handle_info({:flush, client_ref, ref, ack}, state) do
    state = acknowledge(state, ack)

    if :queue.is_empty(state.out) do
      {:noreply, %{state | client: {:poll, client_ref, ref}}}
    else
      send_client(state, client_ref, {:messages, poll_payloads(state), ref, state.out_seq})
      {:noreply, %{state | sent: state.out_seq, client: nil}}
    end
  end

  def handle_info({:expired, client_ref, ref}, %{client: {:poll, client_ref, ref}} = state) do
    {:noreply, %{state | client: nil}}
  end

  def handle_info({:expired, _client_ref, _ref}, state) do
    {:noreply, state}
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
    handle_result(state, handler, handler.handle_info(message, handler_state))
  end

  def terminate(reason, state) do
    %{handler: {handler, handler_state}} = state
    handler.terminate(reason, handler_state)
    :ok
  end

  # The client sends messages again when it did not get the response to its request.
  defp receive_in(from, seq, _frame, %{in_seq: in_seq} = state) when seq <= in_seq do
    report_in(from, :ok, state)
    {:noreply, state}
  end

  # We cannot process the message, as we lost the ones before it.
  defp receive_in(from, seq, _frame, %{in_seq: in_seq} = state) when seq > in_seq + 1 do
    report_in(from, :error, state)
    {:stop, {:shutdown, :out_of_order}, state}
  end

  defp receive_in(from, _seq, frame, state) do
    process_in(from, frame, state)
  end

  defp process_in(from, {body, opcode}, state) do
    %{handler: {handler, handler_state}} = state
    state = %{state | in_seq: state.in_seq + 1}

    case handler.handle_in({body, opcode: opcode}, handler_state) do
      {:reply, status, {opcode, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        report_in(from, if(status == :ok, do: :ok, else: :error), state)
        publish_reply(state, opcode, reply)

      {:ok, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        report_in(from, :ok, state)
        {:noreply, state}

      {:stop, reason, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        report_in(from, :error, state)
        {:stop, reason, state}
    end
  end

  # A request reports the status of its messages in its response.
  defp report_in({:poll, client_ref, ref}, status, state) do
    send_client(state, client_ref, {status, ref})
  end

  defp handle_result(state, handler, result) do
    case result do
      {:push, {opcode, reply}, handler_state} ->
        publish_reply(%{state | handler: {handler, handler_state}}, opcode, reply)

      {:ok, handler_state} ->
        {:noreply, %{state | handler: {handler, handler_state}}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler: {handler, handler_state}}}
    end
  end

  defp publish_reply(state, _opcode, reply) when is_map(reply) do
    IO.warn(
      "Returning a map from the LongPolling serializer is deprecated. " <>
        "Please return JSON encoded data instead (see Phoenix.Socket.Serializer)"
    )

    publish_reply(state, :text, Phoenix.json_library().encode_to_iodata!(reply))
  end

  defp publish_reply(state, opcode, reply) do
    # A client that does not acknowledge must not be able to
    # grow the buffer indefinitely, so we close when it did not acknowledge
    # the messages we sent within the window.
    if expired?(state) do
      stop_expired(state)
    else
      seq = state.out_seq + 1
      payload = IO.iodata_to_binary(reply)
      state = %{state | out: :queue.in({seq, opcode, payload}, state.out), out_seq: seq}

      with {:poll, client_ref, ref} <- state.client do
        send_client(state, client_ref, {:now_available, ref})
      end

      {:noreply, state}
    end
  end

  # The poll response is a JSON document, which cannot hold arbitrary bytes.
  # Binary frames are sent base64-encoded in an object, so clients can tell
  # them apart from text frames, which are sent as strings.
  defp poll_payloads(state) do
    for {_seq, opcode, payload} <- :queue.to_list(state.out) do
      if opcode == :binary, do: %{"binary" => Base.encode64(payload)}, else: payload
    end
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
      {:value, {seq, _opcode, _payload}} when seq <= ack -> drop_until(:queue.drop(queue), ack)
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
      "Phoenix.Transports.Session received a long-poll request without message " <>
        "numbers, which nodes and clients before Phoenix v1.8.18 send, and stops the session. " <>
        "If you do rolling deploys, deploy Phoenix v1.8.18 or a later v1.8 release first. " <>
        "Browsers that still run an older phoenix.js client must reload the page"
    )

    {:stop, {:shutdown, :unnumbered}, state}
  end

  defp send_client(state, client_ref, msg) when is_binary(client_ref),
    do: PubSub.broadcast_from!(state.pubsub_server, self(), client_ref, msg)

  defp send_client(_state, client_ref, msg) when is_pid(client_ref),
    do: send(client_ref, msg)

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp schedule_inactive_shutdown(window_ms) do
    Process.send_after(self(), :shutdown_if_inactive, window_ms)
  end
end
