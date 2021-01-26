defmodule Mix.Phoenix.TemplateSources.PhoenixCompiled do
  @moduledoc false

  use Mix.Phoenix.AggregateTemplateSource

  @impl true
  def template_sources do
    [
      Mix.Tasks.Phx.Gen.Auth,
      Mix.Tasks.Phx.Gen.Channel,
      Mix.Tasks.Phx.Gen.Context,
      Mix.Tasks.Phx.Gen.Embedded,
      Mix.Tasks.Phx.Gen.Json,
      Mix.Tasks.Phx.Gen.Html,
      Mix.Tasks.Phx.Gen.Live,
      Mix.Tasks.Phx.Gen.Presence,
      Mix.Tasks.Phx.Gen.Schema
    ]
  end
end
