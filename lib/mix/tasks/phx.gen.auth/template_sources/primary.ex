defmodule Mix.Tasks.Phx.Gen.Auth.TemplateSources.Primary do
  @moduledoc false

  use Mix.Phoenix.TemplateSource,
    template_patterns: [ "priv/templates/phx.gen.auth/*.*" ],
    exclude_patterns: [
      "priv/templates/phx.gen.auth/context_functions.ex",
      "priv/templates/phx.gen.auth/test_cases.exs"
    ]
end
