defmodule Mix.Tasks.Phx.Gen.Auth.TemplateSources.TestCases do
  @moduledoc false

  use Mix.Phoenix.TemplateSource, template_patterns: [
    "priv/templates/phx.gen.auth/test_cases.exs"
  ]
end
