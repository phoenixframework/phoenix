defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SettingsLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  on_mount {<%= inspect auth_module %>, :mount_current_<%= schema.singular %>}

  def render(assigns) do
    ~H"""
    <h1>Settings</h1>

    <h3>Change email</h3>

    <.form
      id="email_form"
      :let={f}
      for={@email_changeset}
      phx-submit="update_email"
      phx-change="validate_email"
    >
      <%%= if @email_changeset.action == :insert do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>

      <%%= label f, :email %>
      <%%= email_input f, :email, required: true, value: input_value(f, :email) %>
      <%%= error_tag f, :email %>

      <%%= label f, :current_password, for: "current_password_for_email" %>
      <%%= password_input f, :current_password, required: true, name: "current_password", id: "current_password_for_email", value: input_value(f, :current_password) %>
      <%%= error_tag f, :current_password %>

      <div>
        <%%= submit "Change email" %>
      </div>
    </.form>

    <h3>Change password</h3>

    <.form
      id="password_form"
      :let={f}
      for={@password_changeset}
      action={Routes.<%= schema.route_helper %>_session_path(@socket, :create, %{_action: "password_updated"})}
      method="post"
      phx-change="validate_password"
      phx-submit="update_password"
      phx-trigger-action={@trigger_submit}
    >
      <%%= if @password_changeset.action == :insert do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>

      <%%= hidden_input f, :email, value: @current_email %>

      <%%= label f, :password, "New password" %>
      <%%= password_input f, :password, required: true,  value: input_value(f, :password) %>
      <%%= error_tag f, :password %>

      <%%= label f, :password_confirmation, "Confirm new password" %>
      <%%= password_input f, :password_confirmation, required: true, value: input_value(f, :password_confirmation) %>
      <%%= error_tag f, :password_confirmation %>

      <%%= label f, :current_password, for: "current_password_for_password" %>
      <%%= password_input f, :current_password, required: true, name: "current_password", id: "current_password_for_password", value: @current_password%>
      <%%= error_tag f, :current_password %>

      <div>
        <%%= submit "Change password" %>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    <%= schema.singular %> = socket.assigns.current_<%= schema.singular %>

    {:ok,
     socket
     |> assign(:current_password, "")
     |> assign(:current_email, <%= schema.singular %>.email)
     |> assign(:email_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>))
     |> assign(:password_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>))
     |> assign(:trigger_submit, false)}
  end

  def handle_params(%{"token" => token}, _uri, socket) do
    socket =
      case <%= inspect context.alias %>.update_<%= schema.singular %>_email(socket.assigns.current_<%= schema.singular %>, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:noreply, push_redirect(socket, to: Routes.<%= schema.route_helper %>_settings_path(socket, :edit))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("validate_email", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    email_changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(socket.assigns.current_<%= schema.singular %>, <%= schema.singular %>_params)
    {:noreply, assign(socket, :email_changeset, Map.put(email_changeset, :action, :validate))}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = socket.assigns.current_<%= schema.singular %>

    case <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, password, <%= schema.singular %>_params) do
      {:ok, applied_<%= schema.singular %>} ->
        <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(
          applied_<%= schema.singular %>,
          <%= schema.singular %>.email,
          &Routes.<%= schema.route_helper %>_settings_url(socket, :confirm_email, &1)
        )
        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, put_flash(socket, :info, info)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_changeset, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "<%= schema.singular %>" => <%= schema.singular %>_params} = params
    password_changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(socket.assigns.current_<%= schema.singular %>, <%= schema.singular %>_params)

    {:noreply,
     socket
     |> assign(:password_changeset, Map.put(password_changeset, :action, :validate))
     |> assign(:current_password, password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = socket.assigns.current_<%= schema.singular %>

    case <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, password, <%= schema.singular %>_params) do
      {:ok, _user} ->
        {:noreply, assign(socket, :trigger_submit, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end
end
