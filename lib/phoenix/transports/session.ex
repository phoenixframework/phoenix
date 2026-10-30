defmodule Phoenix.Transports.Session do
  @moduledoc false
  #
  # A socket session that outlives the requests or connections of its transport.
  #
  # The session runs the socket handler, so it is the `transport_pid` of the socket
  # and its channels. Transports talk to it through short-lived processes, such as
  # the request processes of long polling or the process of a WebSocket, so a client
  # can resume the session after one of them failed. A WebSocket attaches to the
  # session as its pipe, which receives our messages as we send them, while long
  # polling requests them.
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
  # The numbers do not depend on how a transport groups messages, so a client can
  # resume the session with another request or connection than the one that failed.
  #
  # Long polling addresses the session with a `client_ref`, which is the pid of the
  # request process when it runs on a node we are connected to, or the PubSub
  # topic it subscribed to otherwise. Pipes talk to the session directly, so they
  # must run on a node we are connected to.

  use GenServer, restart: :temporary
  alias Phoenix.PubSub

  # the WebSocket close codes we use when the session stops, see RFC 6455
  @close_codes %{normal: 1000, internal_error: 1011, service_restart: 1012}

  @doc """
  Starts a session for a socket that its transport connected already.
  """
  def start(endpoint, handler, handler_state, options) do
    priv_topic = priv_topic()
    arg = {:connected, endpoint, handler, handler_state, options, priv_topic}

    case DynamicSupervisor.start_child(__MODULE__.Supervisor, {__MODULE__, arg}) do
      {:ok, pid} -> {:ok, pid, priv_topic}
      {:error, _} = error -> error
    end
  end

  @doc false
  def priv_topic do
    "phx:lp:" <>
      Base.encode64(:crypto.strong_rand_bytes(16)) <>
      (System.system_time(:millisecond) |> Integer.to_string())
  end

  @doc """
  Signs the token that clients use to resume the session.
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

  def init({:connected, endpoint, handler, handler_state, options, priv_topic}) do
    {:ok, handler_state} = handler.init(handler_state)
    {:ok, init_state(endpoint, handler, handler_state, options, priv_topic)}
  end

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
    window_ms = Keyword.fetch!(options, :window_ms)

    state = %{
      handler: {handler, handler_state},
      # the messages the client did not acknowledge yet, as {seq, opcode, payload}
      out: :queue.new(),
      # the number of the last message we numbered, sent and the client acknowledged
      out_seq: 0,
      sent: 0,
      acked: 0,
      # when we sent the oldest message the client did not acknowledge yet
      sent_at: nil,
      # the number of the last message we received
      in_seq: 0,
      window_ms: trunc(window_ms * 1.5),
      pubsub_server: endpoint.config(:pubsub_server),
      priv_topic: priv_topic,
      last_client_poll: now_ms(),
      client_ref: nil,
      # the process of a connection that receives our messages as we send them,
      # such as a WebSocket, and its monitor
      pipe: nil,
      # the close code the socket asked for when it stopped
      close_code: nil
    }

    :ok = PubSub.subscribe(state.pubsub_server, priv_topic)
    schedule_inactive_shutdown(state.window_ms)
    state
  end

  ## Incoming messages

  def handle_info({:dispatch, client_ref, _body, ref, seq}, %{in_seq: in_seq} = state)
      when seq <= in_seq do
    # The client sends messages again when it did not get the response to its request.
    broadcast_from!(state, client_ref, {:ok, ref})
    {:noreply, state}
  end

  def handle_info({:dispatch, client_ref, _body, ref, seq}, %{in_seq: in_seq} = state)
      when seq > in_seq + 1 do
    # We cannot process the message, as we lost the ones before it.
    broadcast_from!(state, client_ref, {:error, ref})
    {:stop, {:shutdown, :out_of_order}, state}
  end

  def handle_info({:dispatch, client_ref, body, ref, _seq}, state) do
    dispatch(client_ref, body, ref, state)
  end

  # TODO: Remove in Phoenix 1.10. Phoenix 1.8 nodes and clients dispatch without seq.
  def handle_info({:dispatch, client_ref, body, ref}, state) do
    dispatch(client_ref, body, ref, state)
  end

  def handle_info({:subscribe, client_ref, ref}, state) do
    broadcast_from!(state, client_ref, {:subscribe, ref})
    {:noreply, state}
  end

  # Transports find the session by the pid in the token. A pid can belong to another
  # session after this one stopped, so a client that resumes also sends the topic of
  # the token, which only this session has. We reject a mismatch but keep running for
  # our own client.
  def handle_info({:resume, client_ref, ref, _info, priv_topic}, state)
      when priv_topic != state.priv_topic do
    broadcast_from!(state, client_ref, {:rejected, ref})
    {:noreply, state}
  end

  # A client that resumes the session after a failed request or connection
  # tells us about its new connection, so the socket can check it.
  def handle_info({:resume, client_ref, ref, info, _priv_topic}, state) do
    %{handler: {handler, handler_state}} = state

    result =
      if function_exported?(handler, :handle_resume, 2) do
        handler.handle_resume(info, handler_state)
      else
        {:ok, handler_state}
      end

    case result do
      {:ok, handler_state} ->
        broadcast_from!(state, client_ref, {:resumed, ref})
        # the client gave up on the WebSocket we have, for example to long poll instead
        {:noreply, %{detach(state) | handler: {handler, handler_state}}}

      {:error, _reason} ->
        broadcast_from!(state, client_ref, {:rejected, ref})
        {:stop, {:shutdown, :resume_rejected}, state}
    end
  end

  ## Pipes

  # A connection that receives our messages as we send them, such as a WebSocket.
  # It replaces the previous one, which the client gave up on.
  def handle_info({:pipe_attach, pipe, ref, _ack, priv_topic}, state)
      when priv_topic != state.priv_topic do
    send(pipe, {:rejected, ref})
    {:noreply, state}
  end

  def handle_info({:pipe_attach, pipe, ref, ack, _priv_topic}, state) do
    # the client resumed over a WebSocket, so it stopped polling
    state = %{detach(state) | client_ref: nil}
    send(pipe, {:attached, ref, state.in_seq})
    state = acknowledge(state, ack)
    state = %{state | pipe: {pipe, Process.monitor(pipe)}}

    if :queue.is_empty(state.out) do
      {:noreply, state}
    else
      send(
        pipe,
        {:push_frames,
         for({_seq, opcode, payload} <- :queue.to_list(state.out), do: {opcode, payload})}
      )

      {:noreply, sent(state)}
    end
  end

  # Pipes number the messages they receive, starting after the last one we received
  # when they attached. The pipe the client gave up on can still deliver messages,
  # which the client sends again over the new one, so we drop them like duplicates.
  def handle_info({:pipe_in, pipe, seq, _frame}, %{in_seq: in_seq} = state) when seq <= in_seq do
    send(pipe, {:in_seq, in_seq})
    {:noreply, state}
  end

  def handle_info({:pipe_in, _pipe, seq, _frame}, %{in_seq: in_seq} = state)
      when seq > in_seq + 1 do
    {:stop, {:shutdown, :out_of_order}, %{state | close_code: @close_codes.internal_error}}
  end

  def handle_info({:pipe_in, pipe, _seq, {body, opcode}}, state) do
    %{handler: {handler, handler_state}} = state
    state = %{state | in_seq: state.in_seq + 1}
    send(pipe, {:in_seq, state.in_seq})

    case handler.handle_in({body, opcode: opcode}, handler_state) do
      {:reply, _status, {opcode, reply}, handler_state} ->
        publish_reply(%{state | handler: {handler, handler_state}}, opcode, reply)

      {:ok, handler_state} ->
        {:noreply, %{state | handler: {handler, handler_state}}}

      {:stop, reason, handler_state} ->
        {:stop, reason, %{state | handler: {handler, handler_state}}}
    end
  end

  def handle_info({:pipe_ack, _pipe, ack}, state) do
    {:noreply, acknowledge(state, ack)}
  end

  # The client closes the session, as opposed to losing its connection.
  def handle_info({:pipe_close, pipe}, %{pipe: {pipe, _}} = state) do
    {:stop, {:shutdown, :closed}, %{state | close_code: @close_codes.normal}}
  end

  def handle_info({:pipe_close, _pipe}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, _, _, _}, %{pipe: {_, ref}} = state) do
    {:noreply, %{state | pipe: nil, last_client_poll: now_ms()}}
  end

  ## Outgoing messages

  # The client acknowledges the last message it received with each poll, so we send
  # the messages after it until it did, as the response of a poll can get lost.
  def handle_info({:flush, client_ref, ref, ack}, state) do
    state = acknowledge(%{state | last_client_poll: now_ms()}, ack)

    cond do
      # A poll the client gave up on when it resumed over a WebSocket. It must not
      # take the messages, so it expires. A client that switches to long polling
      # resumes the session first, which detaches the WebSocket.
      state.pipe != nil ->
        {:noreply, state}

      :queue.is_empty(state.out) ->
        {:noreply, %{state | client_ref: {client_ref, ref}}}

      true ->
        broadcast_from!(state, client_ref, {:messages, poll_payloads(state), ref, state.out_seq})
        {:noreply, %{sent(state) | client_ref: nil}}
    end
  end

  # Backwards compat: clients that don't acknowledge get each message once.
  #
  # TODO: Remove in Phoenix 1.10. Phoenix 1.8 nodes and clients flush without ack.
  def handle_info({:flush, client_ref, ref}, state) do
    # we assume the client received the messages we sent before, like it does
    state = acknowledge(%{state | last_client_poll: now_ms()}, state.sent)

    if :queue.is_empty(state.out) do
      {:noreply, %{state | client_ref: {client_ref, ref}}}
    else
      broadcast_from!(state, client_ref, {:messages, poll_payloads(state), ref})
      {:noreply, %{acknowledge(sent(state), state.out_seq) | client_ref: nil}}
    end
  end

  def handle_info({:expired, client_ref, ref}, state) do
    case state.client_ref do
      {^client_ref, ^ref} ->
        {:noreply, %{state | client_ref: nil}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:shutdown_if_inactive, state) do
    cond do
      state.pipe == nil and now_ms() - state.last_client_poll > state.window_ms ->
        {:stop, {:shutdown, :inactive}, state}

      unacknowledged?(state) ->
        {:stop, {:shutdown, :unacknowledged}, state}

      true ->
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

      {:stop, reason, code, handler_state} ->
        state = %{state | handler: {handler, handler_state}, close_code: code}
        {:stop, reason, state}
    end
  end

  def terminate(reason, state) do
    %{handler: {handler, handler_state}} = state

    with {pipe, _ref} <- state.pipe do
      send(pipe, {:session_closed, state.close_code || close_code(reason)})
    end

    handler.terminate(reason, handler_state)
    :ok
  end

  defp close_code(:normal), do: @close_codes.normal
  defp close_code({:shutdown, :restart}), do: @close_codes.service_restart
  defp close_code(_reason), do: @close_codes.internal_error

  defp detach(%{pipe: {pipe, ref}} = state) do
    Process.demonitor(ref, [:flush])
    send(pipe, {:detached, self()})
    %{state | pipe: nil, last_client_poll: now_ms()}
  end

  defp detach(state), do: state

  defp dispatch(client_ref, {body, opcode}, ref, state) do
    %{handler: {handler, handler_state}} = state
    state = %{state | in_seq: state.in_seq + 1}

    case handler.handle_in({body, opcode: opcode}, handler_state) do
      {:reply, status, {opcode, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        status = if status == :ok, do: :ok, else: :error
        broadcast_from!(state, client_ref, {status, ref})
        publish_reply(state, opcode, reply)

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

  # Long polling sends text messages as they are and binary messages in base64
  # with a prefix, which a session can have when it started over a WebSocket.
  defp poll_payloads(state) do
    for {_seq, opcode, payload} <- :queue.to_list(state.out) do
      if opcode == :binary, do: "base64:" <> Base.encode64(payload), else: payload
    end
  end

  # Drops the messages up to the acknowledged one. A late request can acknowledge
  # an older message, and a client cannot acknowledge messages we did not send.
  defp acknowledge(state, ack) when is_integer(ack) and ack > state.acked do
    ack = min(ack, state.sent)
    out = drop_until(state.out, ack)
    # while the client makes progress, the rest of the messages get a new window
    sent_at = if ack < state.sent, do: now_ms()
    %{state | out: out, acked: ack, sent_at: sent_at}
  end

  defp acknowledge(state, _ack), do: state

  defp drop_until(queue, ack) do
    case :queue.peek(queue) do
      {:value, {seq, _opcode, _payload}} when seq <= ack -> drop_until(:queue.drop(queue), ack)
      _ -> queue
    end
  end

  defp sent(state) do
    %{state | sent: state.out_seq, sent_at: state.sent_at || now_ms()}
  end

  defp broadcast_from!(state, client_ref, msg) when is_binary(client_ref),
    do: PubSub.broadcast_from!(state.pubsub_server, self(), client_ref, msg)

  defp broadcast_from!(_state, client_ref, msg) when is_pid(client_ref),
    do: send(client_ref, msg)

  defp publish_reply(state, opcode, reply) when is_map(reply) do
    IO.warn(
      "Returning a map from the LongPolling serializer is deprecated. " <>
        "Please return JSON encoded data instead (see Phoenix.Socket.Serializer)"
    )

    publish_reply(state, opcode, Phoenix.json_library().encode_to_iodata!(reply))
  end

  defp publish_reply(state, opcode, reply) do
    # A client that does not acknowledge must not be able to
    # grow the buffer indefinitely, so we close when it did not acknowledge
    # the messages we sent within the window.
    if unacknowledged?(state) do
      {:stop, {:shutdown, :unacknowledged}, state}
    else
      seq = state.out_seq + 1
      payload = IO.iodata_to_binary(reply)
      state = %{state | out: :queue.in({seq, opcode, payload}, state.out), out_seq: seq}

      case state.pipe do
        {pipe, _ref} ->
          send(pipe, {:push_frames, [{opcode, payload}]})
          {:noreply, sent(state)}

        nil ->
          notify_client_now_available(state)
          {:noreply, state}
      end
    end
  end

  defp unacknowledged?(%{sent_at: nil}), do: false
  defp unacknowledged?(state), do: now_ms() - state.sent_at > state.window_ms

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
