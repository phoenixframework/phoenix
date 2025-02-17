defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Index do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing <%= schema.human_plural %>
      <:actions>
        <.button phx-click={JS.dispatch("click", to: {:inner, "a"})}>
          <.link navigate={~p"<%= schema.route_prefix %>/new"}>
            New <%= schema.human_singular %>
          </.link>
        </.button>
      </:actions>
    </.header>

    <.table
      id="<%= schema.plural %>"
      rows={@streams.<%= schema.collection %>}
      row_click={fn {_id, <%= schema.singular %>} -> JS.navigate(~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}") end}
    ><%= for {k, _} <- schema.attrs do %>
      <:col :let={{_id, <%= schema.singular %>}} label="<%= Phoenix.Naming.humanize(Atom.to_string(k)) %>">{<%= schema.singular %>.<%= k %>}</:col><% end %>
      <:action :let={{_id, <%= schema.singular %>}}>
        <div class="sr-only">
          <.link navigate={~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}"}>Show</.link>
        </div>
        <.link navigate={~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, <%= schema.singular %>}}>
        <.link
          phx-click={JS.push("delete", value: %{id: <%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing <%= schema.human_plural %>")<%= if schema.opts[:primary_key] do %>
     |> stream_configure(:<%= schema.collection %>, dom_id: &"<%= schema.table %>-#{&1.<%= schema.opts[:primary_key] %>}")<% end %>
     |> stream(:<%= schema.collection %>, <%= inspect context.alias %>.list_<%= schema.plural %>())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
    {:ok, _} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)

    {:noreply, stream_delete(socket, :<%= schema.collection %>, <%= schema.singular %>)}
  end
end
