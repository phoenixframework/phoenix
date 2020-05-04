defmodule Mix.Tasks.Compile.Phoenix do
  use Mix.Task
  @recursive true

  @moduledoc """
  Compiles Phoenix source files that support code reloading.
  """

  @doc false
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:phoenix)

    case touch() do
      [] -> {:noop, []}
      _  -> {:ok, []}
    end
  end

  @doc false
  def touch do
    Mix.Phoenix.modules()
    |> modules_for_recompilation
    |> modules_to_file_paths
    |> Stream.map(&touch_if_exists(&1))
    |> Stream.filter(&(&1 == :ok))
    |> Enum.to_list()
  end
  defp touch_if_exists(path) do
    :file.change_time(path, :calendar.local_time())
  end

  defp modules_for_recompilation(modules) do
    Stream.filter modules, fn mod ->
      Code.ensure_loaded?(mod) and
        function_exported?(mod, :__phoenix_recompile__?, 0) and
        mod.__phoenix_recompile__?()
    end
  end

  defp modules_to_file_paths(modules) do
    Stream.map(modules, fn mod -> mod.__info__(:compile)[:source] end)
  end
end
