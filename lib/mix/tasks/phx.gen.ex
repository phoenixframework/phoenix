defmodule Mix.Tasks.Phx.Gen do
  use Mix.Task

  @shortdoc "Lists all available Phoenix generators"

  @moduledoc """
  Lists all available Phoenix generators.
  
  ## CRUD related generators

Sometimes you just want to create an schema to validate an external entity and other times you just need a REST API or an HTML CRUD. check the following table to get an idea of how each of the CRUD related generators relate to each other

| Tasks | Migration | Schema | Context | Controller | View | CRUD Templates | LiveView views/components |
| ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| `phx.gen.schema` | Included | Included |  |  |  |  |  |
| `phx.gen.embedded` |  | Included |  |  |  |  |  |
| `phx.gen.context` | Included | Included | Included |  |  |  |  |
| `phx.gen.json` | Included | Included | Included | Included | Included |  |  |
| `phx.gen.html` | Included | Included | Included | Included | Included | Included |  |
| `phx.gen.live` | Included | Included |  |  |  |  | Included |
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "phx.gen."])
  end
end
