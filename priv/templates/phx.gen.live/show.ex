defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}<%= if scope do %> <%= scope.assign_key %>={@<%= scope.assign_key %>}<% end %>>
      <.header>
        <%= schema.human_singular %> {@<%= schema.singular %>.<%= primary_key %>}
        <:subtitle>This is a <%= schema.singular %> record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>/#{@<%= schema.singular %>}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit <%= schema.singular %>
          </.button>
        </:actions>
      </.header>

      <.list><%= for {k, _} <- schema.attrs do %>
        <:item title="<%= Phoenix.Naming.humanize(Atom.to_string(k)) %>">{@<%= schema.singular %>.<%= k %>}</:item><% end %>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"<%= primary_key %>" => <%= primary_key %>}, _session, socket) do<%= if scope do %>
    if connected?(socket) do
      <%= inspect context.alias %>.subscribe_<%= schema.plural %>(<%= socket_scope %>)
    end
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
     |> push_navigate(to: ~p"<%= scope_socket_route_prefix %><%= schema.route_prefix %>")}
  end

  def handle_info({type, %<%= inspect schema.module %>{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end<% end %>
end
