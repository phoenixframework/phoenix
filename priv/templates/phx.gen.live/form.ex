defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Form do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%%= @page_title %>
        <:subtitle>Use this form to manage <%= schema.singular %> records in your database.</:subtitle>
      </.header>

      <.simple_form for={@form} id="<%= schema.singular %>-form" phx-change="validate" phx-submit="save">
<%= Mix.Tasks.Phx.Gen.Html.indent_inputs(inputs, 8) %>
        <:actions>
          <.button phx-disable-with="Saving...">Save <%= schema.human_singular %></.button>
        </:actions>
      </.simple_form>

      <.back navigate={~p"<%= schema.route_prefix %>"}>Back to <%= schema.plural %></.back>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    save_<%= schema.singular %>(socket, socket.assigns.live_action, <%= schema.singular %>_params)
  end

  defp save_<%= schema.singular %>(socket, :edit, <%= schema.singular %>_params) do
    case <%= inspect context.alias %>.update_<%= schema.singular %>(socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:noreply,
         socket
         |> put_flash(:info, "<%= schema.human_singular %> updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, <%= schema.singular %>))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_<%= schema.singular %>(socket, :new, <%= schema.singular %>_params) do
    case <%= inspect context.alias %>.create_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:noreply,
         socket
         |> put_flash(:info, "<%= schema.human_singular %> created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, <%= schema.singular %>))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(:index, _<%= schema.singular %>), do: ~p"<%= schema.route_prefix %>"
  defp return_path(:show, <%= schema.singular %>), do: ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}"

  @impl true
  def handle_params(params, _url, socket) do
    socket = assign(socket, :return_to, return_to(params["return_to"]))
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(id)

    socket
    |> assign(:page_title, "Edit <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, <%= schema.singular %>)
    |> assign(:form, to_form(<%= inspect context.alias %>.change_<%= schema.singular %>(<%= schema.singular %>)))
  end

  defp apply_action(socket, :new, _params) do
    <%= schema.singular %> = %<%= inspect schema.alias %>{}

    socket
    |> assign(:page_title, "New <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, <%= schema.singular %>)
    |> assign(:form, to_form(<%= inspect context.alias %>.change_<%= schema.singular %>(<%= schema.singular %>)))
  end

  defp return_to("index"), do: :index
  defp return_to("show"), do: :show
  defp return_to(_), do: :show

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
