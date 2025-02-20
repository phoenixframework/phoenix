defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Form do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>Use this form to manage <%= schema.singular %> records in your database.</:subtitle>
    </.header>

    <.simple_form for={@form} id="<%= schema.singular %>-form" phx-change="validate" phx-submit="save">
<%= Mix.Tasks.Phx.Gen.Html.indent_inputs(inputs, 6) %>
      <:actions>
        <.button phx-disable-with="Saving...">Save <%= schema.human_singular %></.button>
      </:actions>
    </.simple_form>

    <.back navigate={return_path(@return_to, @<%= schema.singular %>)}>Back</.back>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"<%= primary_key %>" => <%= primary_key %>}) do
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= primary_key %>)

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

  defp return_path("index", _<%= schema.singular %>), do: ~p"<%= schema.route_prefix %>"
  defp return_path("show", <%= schema.singular %>), do: ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}"
end
