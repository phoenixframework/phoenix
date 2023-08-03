defmodule Mix.Tasks.Phx.Gen do
  use Mix.Task

  @shortdoc "Lists all available Phoenix generators"

  @moduledoc """
  Lists all available Phoenix generators.

  ## CRUD related generators

  The table below shows a summary of the contents created by the CRUD generators:

  | Task | Schema | Migration | Context | Controller | View | LiveView |
  |:------------------ |:-:|:-:|:-:|:-:|:-:|:-:|
  | `phx.gen.embedded` | x |   |   |   |   |   |
  | `phx.gen.schema`   | x | x |   |   |   |   |
  | `phx.gen.context`  | x | x | x |   |   |   |
  | `phx.gen.live`     | x | x | x |   |   | x |
  | `phx.gen.json`     | x | x | x | x | x |   |
  | `phx.gen.html`     | x | x | x | x | x |   |
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "phx.gen."])
  end
end
