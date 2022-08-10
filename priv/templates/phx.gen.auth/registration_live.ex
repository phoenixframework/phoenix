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
      action={~p"<%= schema.route_prefix %>/log_in?_action=registered"}
      method="post"
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
      <.link href={~p"<%= schema.route_prefix %>/log_in"}>Log in</.link> |
      <.link href={~p"<%= schema.route_prefix %>/reset_password"}>Forgot your password?</.link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(%<%= inspect schema.alias %>{})
    socket = assign(socket, changeset: changeset, trigger_submit: false)
    {:ok, socket, temporary_assigns: [changeset: nil]}
  end

  def handle_event("save", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    case <%= inspect context.alias %>.register_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:ok, _} =
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(
            <%= schema.singular %>,
            &url(~p"<%= schema.route_prefix %>/confirm/#{&1}")
          )

        changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(<%= schema.singular %>)
        {:noreply, assign(socket, trigger_submit: true, changeset: changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(%<%= inspect schema.alias %>{}, <%= schema.singular %>_params)
    {:noreply, assign(socket, changeset: Map.put(changeset, :action, :validate))}
  end
end
