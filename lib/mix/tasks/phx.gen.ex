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

  ## Customizing generators
  
  You can override the default templates used by generators.
  
  For example, to customize `phx.gen.live`, you can copy and edit the generator templates
  to your own project's priv folder:
  
  First, create the directory for your custom `phx.gen.live` templates:

  ```console
  $ mkdir -p priv/templates/phx.gen.live
  ```

  Next, copy the default phx.gen.live generator templates into your project so you can customize them:

  ```console
  $ cp -r deps/phoenix/priv/templates/phx.gen.live/* priv/templates/phx.gen.live/
  ```

  Phoenix generators will look for templates in your project's `priv/templates` directory first.
  If a matching template is found, it will be used instead of the default.

  Note generator templates may change between minor or even patch Phoenix releases,
  so custom templates may require updates after upgrading. Use this mechanism at your
  own risk.
  """

  def run(_args) do
    Mix.Task.run("help", ["--search", "phx.gen."])
  end
end
