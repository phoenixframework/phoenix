defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Show do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= schema.human_singular %> {@<%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>}
      <:subtitle>This is a <%= schema.singular %> record from your database.</:subtitle>
      <:actions>
        <.button phx-click={JS.dispatch("click", to: {:inner, "a"})}>
          <.link navigate={~p"<%= schema.route_prefix %>/#{@<%= schema.singular %>}/edit?return_to=show"}>
            Edit <%= schema.singular %>
          </.link>
        </.button>
      </:actions>
    </.header>

    <.list><%= Mix.Phoenix.Web.list_items(schema) |> Mix.Phoenix.indent_text(spaces: 6, top: 1) %>
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
  end<%= Mix.Phoenix.Web.maybe_def_array_values(schema) %>
end
