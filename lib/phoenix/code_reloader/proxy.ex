# This proxy is spawned at startup and replaces (and forwards to)
# the standard_error process.
defmodule Phoenix.CodeReloader.Proxy do
  @moduledoc false
  use GenServer

  def start_link() do
    stderr = Process.whereis(:standard_error)
    Process.unregister(:standard_error)

    GenServer.start_link(__MODULE__, stderr, name: :standard_error)
  end

  def flush do
    GenServer.call(:standard_error, :flush)
  end

  def capture(original_gl) do
    GenServer.call(:standard_error, {:capture, original_gl}, :infinity)
  end

  def forward_to(pid) do
    GenServer.call(:standard_error, {:forward_to, pid}, :infinity)
  end

  def uncapture() do
    GenServer.call(:standard_error, :uncapture, :infinity)
  end

  ## Callbacks

  def init(original_stderr) do
    state =
      %{
        captured: nil, # {pid, originnal_gl}
        pids: [],
        output: "",
        original_stderr: original_stderr,
        proxy: nil,
      }
    {:ok, state}
  end

  def handle_call({:capture, original_gl}, {from, _tag}, state) do
    state = start_capture(from, original_gl, state)

    {:reply, :ok, state}
  end

  def handle_call({:forward_to, pid}, _from, state) do
    state = Map.update(state, :pids, [pid], &[pid | &1])

    {:reply, :ok, state}
  end

  def handle_call(:uncapture, _from, state) do
    broadcast state.pids, {:done, state.output}

    GenServer.stop(state.proxy)

    state = Map.put(state, :output, "")
    state = Map.put(state, :captured, nil)
    state = Map.put(state, :pids, [])

    {:reply, :ok, state}
  end

  def handle_call(:flush, _from, state) do
    {:reply, {:ok, state.output}, state}
  end

  def handle_cast({:stdout, chars}, state) do
    broadcast state.pids, {:chars, :stdout, chars}

    state = %{state | output: state.output <> IO.chardata_to_string(chars)}

    {:noreply, state}
  end

  def handle_info(msg, state = %{original_stderr: stderr}) do
    case msg do
      {:io_request, from, reply, {:put_chars, chars}} ->
        put_chars(stderr, from, reply, chars, state)

      {:io_request, from, reply, {:put_chars, m, f, as}} ->
        put_chars(stderr, from, reply, apply(m, f, as), state)

      {:io_request, from, reply, {:put_chars, _encoding, chars}} ->
        put_chars(stderr, from, reply, chars, state)

      {:io_request, from, reply, {:put_chars, _encoding, m, f, as}} ->
        put_chars(stderr, from, reply, apply(m, f, as), state)

      {:io_request, _from, _reply, _request} = msg ->
        send(stderr, msg)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp put_chars(stderr, from, reply, chars, state) do
    broadcast state.pids, {:chars, :stderr, chars}

    send(stderr, {:io_request, from, reply, {:put_chars, :unicode, chars}})

    state = %{state | output: state.output <> IO.chardata_to_string(chars)}
    {:noreply, state}
  end

  defp broadcast(pids, msg) do
    for pid <- pids do
      send pid, msg
    end
  end

  defp start_capture(pid, original_gl, state) do
    {:ok, proxy} = Phoenix.CodeReloader.GroupLeaderProxy.start_link(self(), pid, original_gl)

    %{state | proxy: proxy}
  end
end
