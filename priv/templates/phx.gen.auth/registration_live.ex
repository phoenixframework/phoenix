defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def render(assigns) do
    ~H"""
    <h1>Register</h1>

    <.form
      id="registration_form"
      :let={f}
      for={@changeset}
      phx-submit="save"
      phx-change="validate"
      phx-trigger-action={@trigger_submit}
      action={Routes.<%= schema.route_helper %>_session_path(@socket, :create, %{_action: "registered"})}
      as={:<%= schema.singular %>}
    >
      <%%= if @changeset.action == :insert do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>

      <%%= label f, :email %>
      <%%= email_input f, :email, required: true %>
      <%%= error_tag f, :email %>

      <%%= label f, :password %>
      <%%= password_input f, :password, required: true, value: input_value(f, :password) %>
      <%%= error_tag f, :password %>

      <div>
        <%%= submit "Register" %>
      </div>
    </.form>

    <p>
      <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link> |
      <.link href={Routes.<%= schema.route_helper %>_reset_password_path(@socket, :new)}>Forgot your password?</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_changeset()
     |> assign(trigger_submit: false), temporary_assigns: [changeset: nil]}
  end

  def handle_event("save", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    case <%= inspect context.alias %>.register_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:ok, _} =
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(
            <%= schema.singular %>,
            &Routes.<%= schema.route_helper %>_confirmation_url(socket, :edit, &1)
          )

        {:noreply, socket |> assign(:trigger_submit, true) |> assign_changeset(<%= schema.singular %>_params)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    {:noreply, assign_changeset(socket, <%= schema.singular %>_params)}
  end

  defp assign_changeset(socket), do: assign_changeset(socket, %{}, nil)

  defp assign_changeset(socket, <%= schema.singular %>_params, action \\ :validate) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(%<%= inspect schema.alias %>{}, <%= schema.singular %>_params)
    assign(socket, :changeset, Map.put(changeset, :action, action))
  end
end
