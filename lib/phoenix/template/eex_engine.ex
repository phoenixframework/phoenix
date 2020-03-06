defmodule Phoenix.Template.EExEngine do
  @moduledoc """
  The Phoenix engine that handles the `.eex` extension.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, name) do
    EEx.compile_file(path, [line: 1] ++ engine_opts(name))
  end

  defp engine_opts(name) do
    case Phoenix.Template.format_encoder(name) do
      Phoenix.Template.HTML ->
        unless Code.ensure_loaded?(Phoenix.HTML.Engine) do
          raise "could not load Phoenix.HTML.Engine to use with .html.eex templates. " <>
                  "You can configure your own format encoder for HTML but we recommend " <>
                  "adding phoenix_html as a dependency as it provides XSS protection."
        end

        trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
        [engine: Phoenix.HTML.Engine, trim: trim]

      _ ->
        [engine: EEx.SmartEngine]
    end
  end
end
