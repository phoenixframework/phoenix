defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Index do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing <%= schema.human_plural %>
      <:actions>
        <.link class={button_classes()} navigate={~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>/new"}>
          New <%= schema.human_singular %>
        </.link>
      </:actions>
    </.header>

    <.table
      id="<%= schema.plural %>"
      rows={@streams.<%= schema.collection %>}
      row_click={fn {_id, <%= schema.singular %>} -> JS.navigate(~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}") end}
    ><%= for {k, _} <- schema.attrs do %>
      <:col :let={{_id, <%= schema.singular %>}} label="<%= Phoenix.Naming.humanize(Atom.to_string(k)) %>">{<%= schema.singular %>.<%= k %>}</:col><% end %>
      <:action :let={{_id, <%= schema.singular %>}}>
        <div class="sr-only">
          <.link navigate={~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}"}>Show</.link>
        </div>
        <.link navigate={~p"<%= scope_assign_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, <%= schema.singular %>}}>
        <.link
          phx-click={JS.push("delete", value: %{<%= primary_key %>: <%= schema.singular %>.<%= primary_key %>}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do<%= if scope do %>
    <%= inspect context.alias %>.subscribe_<%= schema.plural %>(<%= socket_scope %>)
<% end %>
    {:ok,
     socket
     |> assign(:page_title, "Listing <%= schema.human_plural %>")<%= if primary_key != :id do %>
     |> stream_configure(:<%= schema.collection %>, dom_id: &"<%= schema.table %>-#{&1.<%= primary_key %>}")<% end %>
     |> stream(:<%= schema.collection %>, <%= inspect context.alias %>.list_<%= schema.plural %>(<%= socket_scope %>))}
  end

  @impl true
  def handle_event("delete", %{"<%= primary_key %>" => <%= primary_key %>}, socket) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)
    {:ok, _} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>)

    {:noreply, stream_delete(socket, :<%= schema.collection %>, <%= schema.singular %>)}
  end<%= if scope do %>

  @impl true
  def handle_info({type, %<%= inspect schema.module %>{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :<%= schema.collection %>, <%= inspect context.alias %>.list_<%= schema.plural %>(<%= socket_scope %>), reset: true)}
  end<% end %>
end
