defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= schema.human_singular %> <%%= @<%= schema.singular %>.id %>
      <:subtitle>This is a <%= schema.singular %> record from your database.</:subtitle>
      <:actions>
        <.link navigate={~p"<%= schema.route_prefix %>/#{@<%= schema.singular %>}/edit?return_to=show"}>
          <.button>Edit <%= schema.singular %></.button>
        </.link>
      </:actions>
    </.header>

    <.list><%= for {k, _} <- schema.attrs do %>
      <:item title="<%= Phoenix.Naming.humanize(Atom.to_string(k)) %>"><%%= @<%= schema.singular %>.<%= k %> %></:item><% end %>
    </.list>

    <.back navigate={~p"<%= schema.route_prefix %>"}>Back to <%= schema.plural %></.back>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Show <%= schema.human_singular %>")
     |> assign(:<%= schema.singular %>, <%= inspect context.alias %>.get_<%= schema.singular %>!(id))}
  end
end
