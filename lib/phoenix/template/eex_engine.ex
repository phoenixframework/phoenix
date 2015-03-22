defmodule Phoenix.Template.EExEngine do
  @moduledoc """
  The Phoenix engine that handles the `.eex` extension.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, name) do
    EEx.compile_file(path, engine: engine_for(name), line: 1)
  end

  defp engine_for(name) do
    case Phoenix.Template.format_encoder(name) do
      Phoenix.HTML.Engine -> Phoenix.HTML.Engine
      _                   -> EEx.SmartEngine
    end
  end
end
