defmodule Mix.Tasks.Phx.Gen do
  use Mix.Task

  @shortdoc "Lists all available Phoenix generators"

  @moduledoc """
  Lists all available Phoenix generators.
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "phx.gen."])
  end
end
