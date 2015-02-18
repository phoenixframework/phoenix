defmodule Phoenix.CodeReloader.Watcher do
  use GenServer

  @moduledoc """
  Watches paths for ctime changes and calls MFA
  """

  def start_link(paths, mfa, poll_every_ms \\ 500) do
    GenServer.start_link(__MODULE__, [paths, mfa, poll_every_ms])
  end

  def init([paths, mfa, poll_every_ms]) do
    IO.puts "Watching #{inspect paths} every #{poll_every_ms}"
    :timer.send_interval(poll_every_ms, :poll)
    {:ok, {paths, mfa, ctimes(paths)}}
  end

  def handle_info(:poll, {paths, {mod, func, args}, ctimes_before} = state) do
    ctimes_now = ctimes(paths)
    if ctimes_now != ctimes_before do
      IO.puts "CHANGE!"
      apply(mod, func, args)
      {:noreply, {paths, {mod, func, args}, ctimes_now}}
    else
      {:noreply, state}
    end
  end

  defp ctimes(paths) do
    Enum.map(paths, fn path ->
      case File.stat(path) do
        {:ok, stat} -> stat.ctime
        _ -> nil
      end
    end)
  end
end
