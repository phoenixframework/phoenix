defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Registration do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} <%= scope_config.scope.assign_key %>={@<%= scope_config.scope.assign_key %>}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"<%= schema.route_prefix %>/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{<%= scope_config.scope.assign_key %>: %{<%= schema.singular %>: <%= schema.singular %>}}} = socket)
      when not is_nil(<%= schema.singular %>) do
    {:ok, redirect(socket, to: <%= inspect auth_module %>.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    case <%= inspect context.alias %>.register_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:ok, _} =
          <%= inspect context.alias %>.deliver_login_instructions(
            <%= schema.singular %>,
            &url(~p"<%= schema.route_prefix %>/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{<%= schema.singular %>.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"<%= schema.route_prefix %>/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{}, <%= schema.singular %>_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "<%= schema.singular %>")
    assign(socket, form: form)
  end
end
