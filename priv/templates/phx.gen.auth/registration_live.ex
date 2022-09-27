defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"<%= schema.route_prefix %>/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        :let={f}
        id="registration_form"
        for={@changeset}
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"<%= schema.route_prefix %>/log_in?_action=registered"}
        method="post"
        as={:<%= schema.singular %>}
      >
        <%%= if @changeset.action == :insert do %>
          <.error message="Oops, something went wrong! Please check the errors below." />
        <%% end %>

        <.input field={{f, :email}} type="email" label="Email" required />
        <.input
          field={{f, :password}}
          type="password"
          label="Password"
          value={input_value(f, :password)}
          required
        />

        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </:actions>
      </.simple_form>
    </div>
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
