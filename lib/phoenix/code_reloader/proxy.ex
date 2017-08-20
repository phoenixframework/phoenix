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

    send state.proxy, :stop

    state = %{state | output: "", pids: [], proxy: nil}

    {:reply, :ok, state}
  end

  def handle_call(:flush, _from, state) do
    {:reply, {:ok, state.output}, state}
  end

  def handle_cast({:chars, channel, chars}, state) do
    broadcast state.pids, {:chars, channel, chars}

    state = %{state | output: state.output <> chars}

    {:noreply, state}
  end

  def handle_info(msg, state = %{original_stderr: stderr}) do
    handle_io(msg, :stderr, self(), stderr)
    {:noreply, state}
  end

  defp broadcast(pids, msg) do
    for pid <- pids do
      send pid, msg
    end
  end

  defp io_loop(proxy_pid, forward_to) do
    receive do
      :stop ->
        :ok
      msg ->
        handle_io(msg, :stdout, proxy_pid, forward_to)
        io_loop(proxy_pid, forward_to)
    end
  end

  defp handle_io(msg, device, proxy_pid, forward_to) do
    case msg do
      {:io_request, from, reply, {:put_chars, chars}} ->
        put_chars(from, reply, chars, device, proxy_pid, forward_to)

      {:io_request, from, reply, {:put_chars, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), device, proxy_pid, forward_to)

      {:io_request, from, reply, {:put_chars, _encoding, chars}} ->
        put_chars(from, reply, chars, device, proxy_pid, forward_to)

      {:io_request, from, reply, {:put_chars, _encoding, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), device, proxy_pid, forward_to)

      {:io_request, _from, _reply, _request} = msg ->
        send(forward_to, msg)

      _ ->
        nil
    end
  end

  defp put_chars(from, reply, chars, device, proxy_pid, forward_to) do
    GenServer.cast(proxy_pid, {:chars, device, chars})
    send(forward_to, {:io_request, from, reply, {:put_chars, :unicode, chars}})
  end

  defp start_capture(capture_pid, original_gl, state) do
    proxy_pid = self()

    {:ok, proxy} = Task.start_link(fn ->
      Process.group_leader(capture_pid, self())

      io_loop(proxy_pid, Process.group_leader)

      Process.group_leader(capture_pid, original_gl)
    end)

    %{state | proxy: proxy}
  end
end
