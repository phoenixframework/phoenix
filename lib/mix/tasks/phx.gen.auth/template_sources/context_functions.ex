defmodule Mix.Tasks.Phx.Gen.Auth.TemplateSources.ContextFunctions do
  @moduledoc false

  use Mix.Phoenix.TemplateSource, template_patterns: [
    "priv/templates/phx.gen.auth/context_functions.ex"
  ]
end
