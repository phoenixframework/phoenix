defmodule MyApp.RenderView do
  use MyApp.Views

  def render("show.json", _) do
    "{\"foo\":\"bar\"}"
  end
end
