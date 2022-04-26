defmodule Mix.Tasks.Gpanel.Gen do
  use Mix.Task

  @shortdoc "Lists all available Phoenix generators"

  @moduledoc """
  Lists all available Phoenix generators.
  
  ## CRUD related generators

  The table below shows a summary of the contents created by the CRUD generators:

  | Task | Schema | Migration | Context | Controller | View | LiveView |
  |:------------------ |:-:|:-:|:-:|:-:|:-:|:-:|
  | `gpanel.gen.embedded` | ✓ |   |   |   |   |   |
  | `gpanel.gen.schema`   | ✓ | ✓ |   |   |   |   |
  | `gpanel.gen.context`  | ✓ | ✓ | ✓ |   |   |   |
  | `gpanel.gen.live`     | ✓ | ✓ | ✓ |   |   | ✓ |
  | `gpanel.gen.html`     | ✓ | ✓ | ✓ | ✓ | ✓ |   |
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "gpanel.gen."])
  end
end
