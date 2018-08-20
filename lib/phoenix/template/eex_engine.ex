defmodule Phoenix.Template.EExEngine do
  @moduledoc """
  The Phoenix engine that handles the `.eex` extension.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, name) do
    EEx.compile_file(path, engine: engine_for(name), line: 1, trim: true)
  end

  defp engine_for(name) do
    case Phoenix.Template.format_encoder(name) do
      Phoenix.Template.HTML ->
        unless Code.ensure_loaded?(Phoenix.HTML.Engine) do
          raise "could not load Phoenix.HTML.Engine to use with .html.eex templates. " <>
                "You can configure your own format encoder for HTML but we recommend " <>
                "adding phoenix_html as a dependency as it provides XSS protection."
        end
        Phoenix.HTML.Engine
      _ ->
        EEx.SmartEngine
    end
  end
end
