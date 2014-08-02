defmodule Phoenix.View.Helpers do
  alias Phoenix.View

  @moduledoc """
  Imported into all Phoenix Views for rendering support and template
  helper functions.
  """

  @doc """
  Renders template to String, and wraps in extension format

    * module - The View module, ie, MyView
    * template - The String template, ie, "index.html"
    * assigns - The Dictionary of assigns, ie, [title: "Hello!"]

  ## Examples

      <%= render(MyView, "index.html", title: "Hello!") %>
      {:safe, "<h1>Hello!</h1>"}

      <%= render(MyView, "index.txt", title: "Hello!") %>
      "Hello!

  See Phoenix.Views.render/3 for rendering options
  """
  def render(module, template, assigns) do
    module.render(template, assigns)
  end
end
