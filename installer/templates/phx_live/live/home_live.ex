defmodule <%= web_namespace %>.HomeLive do
  use <%= web_namespace %>, :live_view

  def render(assigns) do
    <%= web_namespace %>.PageView.render("home.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
