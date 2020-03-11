defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(assigns) do
    Phoenix.View.render(<%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View, "show.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    {:ok, assign(socket, page_title: gettext("Showing <%= schema.human_singular %>"), id: id, <%= schema.singular %>: <%= schema.singular %>)}
  end

  def handle_params(_params, _, socket) do
    {:noreply, socket}
  end
end
