defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.Settings do
  use <%= inspect context.web_module %>, :live_view

  on_mount {<%= inspect auth_module %>, :require_sudo_mode}

  alias <%= inspect context.module %>

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} <%= scope_config.scope.assign_key %>={@<%= scope_config.scope.assign_key %>}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"<%= schema.route_prefix %>/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_<%= schema.singular %>_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case <%= inspect context.alias %>.update_<%= schema.singular %>_email(socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>, token) do
        {:ok, _<%= schema.singular %>} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"<%= schema.route_prefix %>/settings")}
  end

  def mount(_params, _session, socket) do
    <%= schema.singular %> = socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
    email_changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>, %{}, validate_unique: false)
    password_changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, <%= schema.singular %>.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params

    email_form =
      socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
      |> <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
    true = <%= inspect context.alias %>.sudo_mode?(<%= schema.singular %>)

    case <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>, <%= schema.singular %>_params) do
      %{valid?: true} = changeset ->
        <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          <%= schema.singular %>.email,
          &url(~p"<%= schema.route_prefix %>/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params

    password_form =
      socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
      |> <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
    true = <%= inspect context.alias %>.sudo_mode?(<%= schema.singular %>)

    case <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>, <%= schema.singular %>_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
