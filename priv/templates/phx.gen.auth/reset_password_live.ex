defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  on_mount {<%= inspect auth_module %>, :get_<%= schema.singular %>_by_reset_password_token}

  def render(%{live_action: :new} = assigns) do
    ~H"""
    <h1>Forgot your password?</h1>

    <.form id="reset_password_form" :let={f} for={:<%= schema.singular %>} phx-submit="send_email">
      <%%= label f, :email %>
      <%%= email_input f, :email, required: true %>

      <div>
        <%%= submit "Send instructions to reset password" %>
      </div>
    </.form>

    <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
    <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link>
    """
  end

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <h1>Reset password</h1>
    <.form id="reset_password_form" :let={f} for={@changeset} phx-submit="reset_password">
      <%%= if @changeset.action do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>

      <%%= label f, :password, "New password" %>
      <%%= password_input f, :password, required: true %>
      <%%= error_tag f, :password %>

      <%%= label f, :password_confirmation, "Confirm new password" %>
      <%%= password_input f, :password_confirmation, required: true %>
      <%%= error_tag f, :password_confirmation %>

      <div>
        <%%= submit "Reset password" %>
      </div>
    </.form>

    <.link href={Routes.<%= schema.route_helper %>_registration_path(@socket, :new)}>Register</.link> |
    <.link href={Routes.<%= schema.route_helper %>_login_path(@socket, :new)}>Log in</.link>

    """
  end

  def mount(_params, _session, socket) do
    if socket.assigns.live_action == :edit do
      changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(socket.assigns.<%= schema.singular %>)
      {:ok, assign(socket, :changeset, changeset)}
    else
      {:ok, socket}
    end
  end

  # Do not log in the <%= schema.singular %> after reset password to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def handle_event("reset_password", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    case <%= inspect context.alias %>.reset_<%= schema.singular %>_password(socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Password reset successfully.")
          |> redirect(to: Routes.<%= schema.route_helper %>_login_path(socket, :new))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("send_email", %{"<%= schema.singular %>" => %{"email" => email}}, socket) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(
        <%= schema.singular %>,
        &Routes.<%= schema.route_helper %>_reset_password_url(socket, :edit, &1)
      )
    end

    socket =
      socket
      |> put_flash(
        :info,
        "If your email is in our system, you will receive instructions to reset your password shortly."
      )
      |> redirect(to: "/")

    {:noreply, socket}
  end
end
