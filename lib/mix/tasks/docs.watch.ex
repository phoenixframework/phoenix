defmodule PhoenixGuides.Watcher do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ignored)
  end

  def init(_) do
    :ok = Application.ensure_started(:fs)
    :ok = :fs.subscribe()
    docs_path = File.cwd!() <> "/docs"
    {:ok, %{docs_path: docs_path}}
  end

  def handle_info({_pid, {:fs, :file_event}, {path, _event}}, %{docs_path: docs_path} = state) do
    path = to_string(path)
    if String.contains?(path, docs_path) do
      IO.puts "#{path} changed. Rebuilding docs."
      Mix.Task.rerun("docs")
    end
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end

defmodule Mix.Tasks.Docs.Watch do
  use Mix.Task

  @moduledoc """
  A task for building the docs whenever files change
  """
  @shortdoc "Automatically build docs on file changes"

  def run(_args) do
    Mix.Tasks.Docs.run([])
    PhoenixGuides.Watcher.start_link()
    unless Code.ensure_loaded?(IEx) && IEx.started? do
      :timer.sleep(:infinity)
    end
  end
end
