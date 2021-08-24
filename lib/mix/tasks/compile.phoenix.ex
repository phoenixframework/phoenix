defmodule Mix.Tasks.Compile.Phoenix do
  use Mix.Task
  @recursive true

  @moduledoc """
  Compiles Phoenix source files that support code reloading.

  If you are using Elixir v1.11+ or later, there is no longer
  a need to use this module as this functionality is now provided
  by Elixir. Just remember to update `__phoenix_recompile__?` to
  `__mix_recompile__?` in any module that may define it.
  """

  # TODO: Deprecate this module once we require Elixir v1.11+
  @mix_recompile Version.match?(System.version(), ">= 1.11.0")

  @doc false
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:phoenix)

    case touch() do
      [] -> {:noop, []}
      _ -> {:ok, []}
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
    Stream.filter(modules, fn mod ->
      Code.ensure_loaded?(mod) and (phoenix_recompile?(mod) or mix_recompile?(mod))
    end)
  end

  defp phoenix_recompile?(mod) do
    function_exported?(mod, :__phoenix_recompile__?, 0) and mod.__phoenix_recompile__?()
  end

  if @mix_recompile do
    # Recompile is provided by Mix, we don't need to do anything
    defp mix_recompile?(_mod), do: false
  else
    defp mix_recompile?(mod) do
      function_exported?(mod, :__mix_recompile__?, 0) and mod.__mix_recompile__?()
    end
  end

  defp modules_to_file_paths(modules) do
    Stream.map(modules, fn mod -> mod.__info__(:compile)[:source] end)
  end
end
