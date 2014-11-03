defmodule Mix.Tasks.Compile.Phoenix do
  use Mix.Task
  @recursive true

  @moduledoc """
  Compiles Phoenix source files that support code reloading
  """

  def run(_args) do
    Application.ensure_all_started(:phoenix)
    if Application.get_env(:phoenix, :code_reloader) do
      reload
    else
      :noop
    end
  end

  defp reload do
    case Phoenix.CodeReloader.touch do
      [] -> :noop
      _  -> :ok
    end
  end
end
