defmodule <%= web_namespace %>.PageLive.Index do
  use <%= web_namespace %>, :live_view

  def render(assigns) do
    <%= web_namespace %>.PageView.render("index.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: %{})}
  end

  def handle_event("suggest", %{"q" => query}, socket) do
    {:noreply, assign(socket, results: search(query), query: query)}
  end

  def handle_event("search", %{"q" => query}, socket) do
    new_socket =
      case search(query) do
        %{^query => app} -> redirect(socket, external: "https://hexdocs.pm/#{app}/#{query}.html")
        _ -> assign(socket, results: %{}, query: query)
      end

    {:noreply, new_socket}
  end

  defp search(query) do
    if not <%= web_namespace %>.Endpoint.config(:code_reloader) do
      raise "action disabled when not in development"
    end

    for {app, _, _} <- Application.started_applications(),
        module <- Application.spec(app, :modules),
        module |> Atom.to_string() |> String.starts_with?("Elixir." <> query),
        into: %{},
        do: {inspect(module), app}
  end
end
