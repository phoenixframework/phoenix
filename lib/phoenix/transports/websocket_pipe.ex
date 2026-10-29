defmodule Phoenix.Transports.WebSocket.Pipe do
  @moduledoc false
  #
  # The WebSocket of a resumable socket.
  #
  # The socket runs in a `Phoenix.Transports.Session`, which outlives the WebSocket, so
  # the client can resume it over a new WebSocket. The pipe forwards the messages of
  # the client to the session, and the messages of the session to the client.
  #
  # Besides the messages of the socket, the pipe and the client exchange control
  # messages, which are V2 messages without refs on the "phoenix" topic:
  #
  #   * "phx_session" - the first message of a new session, with its resume token
  #   * "phx_resume" - the first message of the client on a new WebSocket, with the
  #     token and the number of the last message it received
  #   * "phx_resumed" - the answer to "phx_resume", with the number of the last
  #     message the session received
  #   * "phx_ack" - the number of the last message the client or the session received
  #   * "phx_close" - the client closes the socket, as opposed to losing its WebSocket
  #   * "phx_gone" - the session stopped or the client cannot resume it, with the
  #     close code of the session if it stopped
  #
  # Control messages are not numbered.

  @behaviour WebSock

  alias Phoenix.Transports.Session

  @control_prefix "[null,null,\"phoenix\",\"phx_"

  # the WebSocket close codes we use, see RFC 6455
  @close_codes %{
    normal: 1000,
    invalid_payload: 1007,
    policy_violation: 1008,
    internal_error: 1011
  }

  @impl true
  def init({:new, session, token, opts}) do
    state = new_state(opts)

    case attach(state, session, 0) do
      {:ok, state} -> {:push, [control("phx_session", %{token: token})], state}
      :error -> gone(state, @close_codes.internal_error)
    end
  end

  def init({:resume, endpoint, opts, info}) do
    # the client must send the resume message right after connecting
    timer = Process.send_after(self(), :resume_timeout, Keyword.fetch!(opts, :window_ms))
    {:ok, %{new_state(opts) | resume: {endpoint, info, timer}}}
  end

  defp new_state(opts) do
    %{
      opts: opts,
      session: nil,
      session_ref: nil,
      # set until the client resumed the session
      resume: nil,
      # the number of the last message we forwarded to the session
      in_seq: 0,
      # the number of the last message the session confirmed, and whether
      # we are about to tell the client about it
      confirmed: 0,
      ack_scheduled: false
    }
  end

  @impl true
  def handle_in({@control_prefix <> _ = text, opcode: :text}, state) do
    case Phoenix.json_library().decode(text) do
      {:ok, [nil, nil, "phoenix", event, payload]} -> handle_control(event, payload, state)
      _ -> {:stop, :normal, @close_codes.invalid_payload, state}
    end
  end

  def handle_in(_frame, %{resume: {_, _, _}} = state) do
    # the client must resume the session before sending messages
    gone(state, nil)
  end

  def handle_in({payload, opcode: opcode}, state) do
    seq = state.in_seq + 1
    send(state.session, {:pipe_in, self(), seq, {payload, opcode}})
    {:ok, %{state | in_seq: seq}}
  end

  defp handle_control("phx_resume", %{"token" => token, "ack" => ack}, %{resume: resume} = state)
       when is_binary(token) and is_integer(ack) and resume != nil do
    {endpoint, info, timer} = resume
    Process.cancel_timer(timer)
    state = %{state | resume: nil}

    with {:ok, session} <- verify_token(endpoint, token, state.opts),
         :ok <- check_resume(session, info, state.opts),
         {:ok, state} <- attach(state, session, ack) do
      {:push, [control("phx_resumed", %{seq: state.in_seq})], state}
    else
      _ -> gone(state, nil)
    end
  end

  defp handle_control("phx_ack", %{"ack" => ack}, %{session: session} = state)
       when is_integer(ack) and session != nil do
    send(session, {:pipe_ack, self(), ack})
    {:ok, state}
  end

  defp handle_control("phx_close", _payload, %{session: session} = state) when session != nil do
    send(session, {:pipe_close, self()})
    {:stop, :normal, state}
  end

  defp handle_control(_event, _payload, state) do
    {:stop, :normal, @close_codes.policy_violation, state}
  end

  @impl true
  def handle_info({:push_frames, frames}, state) do
    {:push, frames, state}
  end

  def handle_info({:in_seq, seq}, state) do
    # we tell the client once for the messages the session confirmed in a row
    state = %{state | confirmed: max(state.confirmed, seq)}

    if state.ack_scheduled do
      {:ok, state}
    else
      send(self(), :send_ack)
      {:ok, %{state | ack_scheduled: true}}
    end
  end

  def handle_info(:send_ack, state) do
    {:push, [control("phx_ack", %{seq: state.confirmed})], %{state | ack_scheduled: false}}
  end

  def handle_info({:session_closed, code}, state) do
    gone(state, code)
  end

  def handle_info({:DOWN, ref, _, _, _}, %{session_ref: ref} = state) do
    gone(state, @close_codes.internal_error)
  end

  def handle_info({:detached, session}, %{session: session} = state) do
    # the client resumed the session over another WebSocket
    {:stop, :normal, state}
  end

  def handle_info(:resume_timeout, %{resume: {_, _, _}} = state) do
    {:stop, :normal, @close_codes.policy_violation, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  defp attach(state, session, ack) do
    ref = Process.monitor(session)
    send(session, {:pipe_attach, self(), ref, ack})

    receive do
      {:attached, ^ref, in_seq} ->
        {:ok, %{state | session: session, session_ref: ref, in_seq: in_seq, confirmed: in_seq}}

      {:DOWN, ^ref, _, _, _} ->
        :error
    after
      Keyword.fetch!(state.opts, :window_ms) ->
        Process.demonitor(ref, [:flush])
        :error
    end
  end

  defp verify_token(endpoint, token, opts) do
    case Session.verify_token(endpoint, token, opts) do
      {:ok, {:v1, _id, session, _priv_topic}} when is_pid(session) ->
        # we talk to the session directly, so it must run on a node we are connected to
        if node(session) == node() or node(session) in Node.list() do
          {:ok, session}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp check_resume(session, info, opts) do
    ref = Process.monitor(session)
    send(session, {:resume, self(), ref, info})

    receive do
      {:resumed, ^ref} ->
        Process.demonitor(ref, [:flush])
        :ok

      {:rejected, ^ref} ->
        Process.demonitor(ref, [:flush])
        :error

      {:DOWN, ^ref, _, _, _} ->
        :error
    after
      Keyword.fetch!(opts, :window_ms) ->
        Process.demonitor(ref, [:flush])
        :error
    end
  end

  # The client connects again with a new session when it cannot resume,
  # and closes with the code of the session if it stopped.
  defp gone(state, code) do
    payload = if code, do: %{code: code}, else: %{}
    {:stop, :normal, code || @close_codes.normal, [control("phx_gone", payload)], state}
  end

  defp control(event, payload) do
    {:text, Phoenix.json_library().encode_to_iodata!([nil, nil, "phoenix", event, payload])}
  end
end
