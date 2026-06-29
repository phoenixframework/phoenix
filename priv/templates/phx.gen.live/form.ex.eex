defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Form do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}<%= if scope do %> <%= scope.assign_key %>={@<%= scope.assign_key %>}<% end %>>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage <%= schema.singular %> records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="<%= schema.singular %>-form" phx-change="validate" phx-submit="save">
<%= Mix.Tasks.Phx.Gen.Html.indent_inputs(inputs, 8) %>
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save <%= schema.human_singular %></.button>
          <.button navigate={return_path(<%= assign_scope_prefix %>@return_to, @<%= schema.singular %>)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
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
    <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= context_scope_prefix %><%= primary_key %>)

    socket
    |> assign(:page_title, "Edit <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, <%= schema.singular %>)
    |> assign(:form, to_form(<%= inspect context.alias %>.change_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>)))
  end

  defp apply_action(socket, :new, _params) do
    <%= schema.singular %> = %<%= inspect schema.alias %>{<%= if scope do %><%= scope.schema_key %>: <%= socket_scope %>.<%= Enum.join(scope.access_path, ".") %><% end %>}

    socket
    |> assign(:page_title, "New <%= schema.human_singular %>")
    |> assign(:<%= schema.singular %>, <%= schema.singular %>)
    |> assign(:form, to_form(<%= inspect context.alias %>.change_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>)))
  end

  @impl true
  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>(<%= context_scope_prefix %>socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    save_<%= schema.singular %>(socket, socket.assigns.live_action, <%= schema.singular %>_params)
  end

  defp save_<%= schema.singular %>(socket, :edit, <%= schema.singular %>_params) do
    case <%= inspect context.alias %>.update_<%= schema.singular %>(<%= context_scope_prefix %>socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:noreply,
         socket
         |> put_flash(:info, "<%= schema.human_singular %> updated successfully")
         <%= if scope do %>|> push_navigate(
           to: return_path(<%= context_scope_prefix %>socket.assigns.return_to, <%= schema.singular %>)
         )}<% else %>|> push_navigate(to: return_path(socket.assigns.return_to, <%= schema.singular %>))}<% end %>

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_<%= schema.singular %>(socket, :new, <%= schema.singular %>_params) do
    case <%= inspect context.alias %>.create_<%= schema.singular %>(<%= context_scope_prefix %><%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:noreply,
         socket
         |> put_flash(:info, "<%= schema.human_singular %> created successfully")
         <%= if scope do %>|> push_navigate(
           to: return_path(<%= context_scope_prefix %>socket.assigns.return_to, <%= schema.singular %>)
         )}<% else %>|> push_navigate(to: return_path(socket.assigns.return_to, <%= schema.singular %>))}<% end %>

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(<%= scope_param_prefix %>"index", _<%= schema.singular %>), do: ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>"
  defp return_path(<%= scope_param_prefix %>"show", <%= schema.singular %>), do: ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}"
end
