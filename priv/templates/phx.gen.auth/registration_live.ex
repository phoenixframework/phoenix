defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Registration do
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
          <.link navigate={~p"<%= schema.route_prefix %>/log-in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:email]} type="email" label="Email" autocomplete="username" required />

        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{<%= schema.singular %>: <%= schema.singular %>}}} = socket)
      when not is_nil(<%= schema.singular %>) do
    {:ok, redirect(socket, to: <%= inspect auth_module %>.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{})

    socket =
      socket
      |> assign(check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

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
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{}, <%= schema.singular %>_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "<%= schema.singular %>")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
