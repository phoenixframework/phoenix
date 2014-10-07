defmodule Mix.Tasks.Compile.Phoenix do
  use Mix.Task

  @recursive true

  @moduledoc """
  Compiles Phoenix source files that support code reloading
  """

  @doc """
  Runs the compile task
  """
  def run(_args) do
    case Phoenix.CodeReloader.touch_modules_for_recompile do
      [] -> :noop
      _  -> :ok
    end
  end
end
