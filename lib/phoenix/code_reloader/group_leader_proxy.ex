# Spawned by the Proxy when capture is started,
# to capture stdout of the compilation process.
# Restores the original group leader when terminated after compilation.
# Output is forwarded to the parent proxy with the :stdout message.
defmodule Phoenix.CodeReloader.GroupLeaderProxy do
  @moduledoc false
  use GenServer

  def start_link(parent, capture_pid, original_gl) do
    GenServer.start_link(__MODULE__, {parent, capture_pid, original_gl})
  end

  ## Callbacks

  def init({parent, capture_pid, original_gl}) do
    Process.group_leader(capture_pid, self())

    state =
      %{
        capture_pid: capture_pid,
        original_gl: original_gl,
        parent: parent,
        output: "",
      }

    {:ok, state}
  end

  def terminate(_reason, state) do
    Process.group_leader(state.capture_pid, state.original_gl)
  end

  def handle_info(msg, state) do
    case msg do
      {:io_request, from, reply, {:put_chars, chars}} ->
        put_chars(from, reply, chars, state)

      {:io_request, from, reply, {:put_chars, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), state)

      {:io_request, from, reply, {:put_chars, _encoding, chars}} ->
        put_chars(from, reply, chars, state)

      {:io_request, from, reply, {:put_chars, _encoding, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), state)

      {:io_request, _from, _reply, _request} = msg ->
        send(Process.group_leader, msg)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp put_chars(from, reply, chars, state) do
    GenServer.cast(state.parent, {:stdout, chars})

    send(Process.group_leader, {:io_request, from, reply, {:put_chars, :unicode, chars}})
    state = %{state | output: state.output <> IO.chardata_to_string(chars)}

    {:noreply, state}
  end
end
