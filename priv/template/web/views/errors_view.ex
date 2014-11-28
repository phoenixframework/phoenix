defmodule <%= application_module %>.ErrorsView do
  use <%= application_module %>.View

  def render("404.html", _assigns) do
    "Page not found - 404"
  end

  def render("500.html", _assigns) do
    "Server internal error - 500"
  end

  # Render all other templates as 500
  def render(_, assigns) do
    render "500.html", assigns
  end
end
