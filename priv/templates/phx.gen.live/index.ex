defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Index do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    {:noreply, handle_action(socket.assigns.live_view_action, params, socket)}
  end

  defp handle_action(:edit, %{"id" => id}, socket) do
    socket
    |> assign(:page_title, "Edit <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, <%= inspect context.alias %>.get_<%= schema.singular %>!(id))
    |> assign_new(:<%= schema.plural %>, &fetch_<%= schema.plural %>/0)
  end

  defp handle_action(:new, _params, socket) do
    socket
    |> assign(:page_title, "New <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, %<%= inspect schema.alias %>{})
    |> assign_new(:<%= schema.plural %>, &fetch_<%= schema.plural %>/0)
  end

  defp handle_action(:index, _params, socket) do
    socket
    |> assign(:page_title, "Listing <%= schema.human_plural %>")
    |> assign(:<%= schema.singular %>, nil)
    |> assign(:<%= schema.plural %>, fetch_<%= schema.plural %>())
  end

  def handle_event("delete", %{"id" => id}, socket) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    {:ok, _} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)

    {:noreply, assign(socket, :<%= schema.plural %>, fetch_<%=schema.plural %>())}
  end

  defp fetch_<%= schema.plural %> do
    <%= inspect context.alias %>.list_<%= schema.plural %>()
  end
end
