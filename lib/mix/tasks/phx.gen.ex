defmodule Mix.Tasks.Phx.Gen do
  use Mix.Task

  @shortdoc "Lists all available Phoenix generators"

  @moduledoc """
  Lists all available Phoenix generators.
  
  ## CRUD related generators

  The table below shows a summary of the contents created by the CRUD generators:

  | Task | Schema | Migration | Context | Controller | View | LiveView |
  |:------------------ |:-:|:-:|:-:|:-:|:-:|:-:|
  | `phx.gen.embedded` | ✓ |   |   |   |   |   |
  | `phx.gen.schema`   | ✓ | ✓ |   |   |   |   |
  | `phx.gen.context`  | ✓ | ✓ | ✓ |   |   |   |
  | `phx.gen.live`     | ✓ | ✓ | ✓ |   |   | ✓ |
  | `phx.gen.json`     | ✓ | ✓ | ✓ | ✓ | ✓ |   |
  | `phx.gen.html`     | ✓ | ✓ | ✓ | ✓ | ✓ |   |
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "phx.gen."])
  end
end
