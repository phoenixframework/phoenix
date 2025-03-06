defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= schema.human_singular %> {@<%= schema.singular %>.<%= primary_key %>}
      <:subtitle>This is a <%= schema.singular %> record from your database.</:subtitle>
      <:actions>
        <.link class={button_classes()} navigate={~p"<%= schema.route_prefix %>/#{@<%= schema.singular %>}/edit?return_to=show"}>
          Edit <%= schema.singular %>
        </.link>
      </:actions>
    </.header>

    <.list><%= for {k, _} <- schema.attrs do %>
      <:item title="<%= Phoenix.Naming.humanize(Atom.to_string(k)) %>">{@<%= schema.singular %>.<%= k %>}</:item><% end %>
    </.list>

    <.back navigate={~p"<%= schema.route_prefix %>"}>Back to <%= schema.plural %></.back>
    """
  end

  @impl true
  def mount(%{"<%= primary_key %>" => <%= primary_key %>}, _session, socket) do<%= if scope do %>
    <%= inspect context.alias %>.subscribe_<%= schema.plural %>(<%= socket_scope %>)
<% end %>
    {:ok,
     socket
     |> assign(:page_title, "Show <%= schema.human_singular %>")
     |> assign(:<%= schema.singular %>, <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>))}
  end<%= if scope do %>

  @impl true
  def handle_info(
        {:updated, %<%= inspect schema.module %>{<%= primary_key %>: <%= primary_key %>} = <%= schema.singular %>},
        %{assigns: %{<%= schema.singular %>: %{<%= primary_key %>: <%= primary_key %>}}} = socket
      ) do
    {:noreply, assign(socket, :<%= schema.singular %>, <%= schema.singular %>)}
  end

  def handle_info(
        {:deleted, %<%= inspect schema.module %>{<%= primary_key %>: <%= primary_key %>}},
        %{assigns: %{<%= schema.singular %>: %{<%= primary_key %>: <%= primary_key %>}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current <%= schema.singular %> was deleted.")
     |> push_navigate(to: ~p"<%= schema.route_prefix %>")}
  end<% end %>
end
