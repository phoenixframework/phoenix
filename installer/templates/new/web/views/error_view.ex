defmodule <%= application_module %>.ErrorView do
  use <%= application_module %>.Web, :view

  def render("404.html", _assigns) do
    "Page not found - 404"
  end

  def render("500.html", _assigns) do
    "Server internal error - 500"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
