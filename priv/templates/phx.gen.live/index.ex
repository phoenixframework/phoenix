defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Index do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def render(assigns) do
    Phoenix.View.render(<%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View, "index.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Listing <%= schema.human_plural %>"))
     |> assign(<%= schema.singular %>: nil)}
  end

  def handle_params(params, _, socket) do
    <%= schema.singular %> =
      case socket.assigns.live_view_action do
        :edit -> <%= inspect context.alias %>.get_<%= schema.singular %>!(params["id"])
        :new -> %<%= inspect schema.alias %>{}
        :index -> nil
      end

    {:noreply, fetch(assign(socket, <%= schema.singular %>: <%= schema.singular %>))}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, <%= schema.singular %>_id: id)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    {:ok, _} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)

    {:noreply, fetch(socket)}
  end

  defp fetch(socket) do
    assign(socket, <%= schema.plural %>: <%= inspect context.alias %>.list_<%= schema.plural %>())
  end
end
