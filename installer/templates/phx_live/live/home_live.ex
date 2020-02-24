defmodule <%= web_namespace %>.HomeLive do
  use <%= web_namespace %>, :live_view

  def render(assigns) do
    <%= web_namespace %>.PageView.render("home.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end

defmodule <%= web_namespace %>.HomeLive.DepsCheck do
  use <%= web_namespace %>, :live_component

  def render(assigns) do
    ~L"""
    <h2>Results of <code>mix hex.outdated</code></h2>
    <pre><%%= @deps %></pre>
    """
  end

  def update(_assigns, socket) do
    {deps, _} = System.cmd("mix", ["hex.outdated"])
    {:ok, assign(socket, deps: deps)}
  end
end
