defmodule Phoenix.Transports.LongPoll.Server do
  @moduledoc false

  use GenServer, restart: :temporary
  alias Phoenix.PubSub

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
          # the messages we did not send yet, newest first
          pending: [],
          # the messages we sent with the last batch that the client did not acknowledge yet,
          # newest first, and when we first sent them
          sent: [],
          sent_at: nil,
          # the number of the last batch we sent
          batch: 0,
          # the seq of the last message we received, to drop the ones the client resends
          last_in: 0,
          handler: {handler, handler_state},
          window_ms: trunc(window_ms * 1.5),
          pubsub_server: endpoint.config(:pubsub_server),
          priv_topic: priv_topic,
          last_client_poll: now_ms(),
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

  # The client sends the same message again when it did not get the response to its POST.
  def handle_info({:dispatch, client_ref, _body, ref, seq}, %{last_in: last_in} = state)
      when seq <= last_in do
    broadcast_from!(state, client_ref, {:ok, ref})
    {:noreply, state}
  end

  def handle_info({:dispatch, client_ref, body, ref, seq}, state) do
    handle_info({:dispatch, client_ref, body, ref}, %{state | last_in: seq})
  end

  # TODO: Merge into the clause above in Phoenix 1.10. Phoenix 1.8 nodes and
  # clients dispatch without seq.
  def handle_info({:dispatch, client_ref, {body, opcode}, ref}, state) do
    %{handler: {handler, handler_state}} = state

    case handler.handle_in({body, opcode: opcode}, handler_state) do
      {:reply, status, {_, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        status = if status == :ok, do: :ok, else: :error
        broadcast_from!(state, client_ref, {status, ref})
        publish_reply(state, reply)

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

  # The client acknowledges the last batch it received with each poll, so we send the
  # messages again until it did, as the response of a poll can get lost.
  def handle_info({:flush, client_ref, ref, ack}, state) do
    state = %{state | last_client_poll: now_ms()}

    state =
      if ack == state.batch do
        # The client received the last batch, so we can drop it.
        %{state | sent: [], sent_at: nil}
      else
        # The response with the last batch got lost,
        # so we send its messages again.
        state
      end

    case state do
      %{sent: [_ | _] = sent} ->
        # A timed-out poll can still reach us after its retry. Keep each batch
        # immutable so that acknowledging an earlier response drops exactly
        # the messages the client received, even when requests arrive late.
        broadcast_from!(state, client_ref, {:messages, Enum.reverse(sent), ref, state.batch})
        {:noreply, %{state | client_ref: nil}}

      %{pending: []} ->
        {:noreply, %{state | client_ref: {client_ref, ref}}}

      %{pending: sent} ->
        batch = state.batch + 1
        broadcast_from!(state, client_ref, {:messages, Enum.reverse(sent), ref, batch})

        {:noreply,
         %{
           state
           | sent: sent,
             sent_at: now_ms(),
             pending: [],
             batch: batch,
             client_ref: nil
         }}
    end
  end

  # Backwards compat: clients that don't acknowledge get each message once.
  #
  # TODO: Remove in Phoenix 1.10. Phoenix 1.8 nodes and clients flush without ack.
  def handle_info({:flush, client_ref, ref}, state) do
    state = %{state | sent: [], sent_at: nil, last_client_poll: now_ms()}

    case state.pending do
      [] ->
        {:noreply, %{state | client_ref: {client_ref, ref}}}

      pending ->
        broadcast_from!(state, client_ref, {:messages, Enum.reverse(pending), ref})
        {:noreply, %{state | client_ref: nil, pending: []}}
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
      now_ms() - state.last_client_poll > state.window_ms ->
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
      {:push, {_, reply}, handler_state} ->
        state = %{state | handler: {handler, handler_state}}
        publish_reply(state, reply)

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

  defp publish_reply(state, reply) when is_map(reply) do
    IO.warn(
      "Returning a map from the LongPolling serializer is deprecated. " <>
        "Please return JSON encoded data instead (see Phoenix.Socket.Serializer)"
    )

    publish_reply(state, Phoenix.json_library().encode_to_iodata!(reply))
  end

  defp publish_reply(state, reply) do
    # A client that does not acknowledge must not be able to
    # grow the buffer indefinitely, so we close when it did not acknowledge
    # a batch within the window.
    if unacknowledged?(state) do
      {:stop, {:shutdown, :unacknowledged}, state}
    else
      notify_client_now_available(state)
      {:noreply, %{state | pending: [IO.iodata_to_binary(reply) | state.pending]}}
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
