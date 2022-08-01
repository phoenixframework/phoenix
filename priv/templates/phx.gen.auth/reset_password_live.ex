defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordLive do
  use <%= inspect context.web_module %>, :live_view

  alias <%= inspect context.module %>

  def render(assigns) do
    ~H"""
    <h1>Reset password</h1>
    <.form id="reset_password_form" :let={f} for={@changeset} phx-submit="reset_password" phx-change="validate">
      <%%= if @changeset.action == :insert do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>

      <%%= label f, :password, "New password" %>
      <%%= password_input f, :password, required: true, value: input_value(f, :password) %>
      <%%= error_tag f, :password %>

      <%%= label f, :password_confirmation, "Confirm new password" %>
      <%%= password_input f, :password_confirmation, required: true, value: input_value(f, :password_confirmation) %>
      <%%= error_tag f, :password_confirmation %>

      <div>
        <%%= submit "Reset password" %>
      </div>
    </.form>

    <p>
      <.link href={~p"<%= schema.route_prefix %>/register"}>Register</.link> |
      <.link href={~p"<%= schema.route_prefix %>/log_in"}>Log in</.link>
    </p>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_<%= schema.singular %>_and_token(socket, params)

    socket =
      case socket.assigns do
        %{<%= schema.singular %>: <%= schema.singular %>} ->
          assign(socket, :changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>))

        _ ->
          socket
      end

    {:ok, socket, temporary_assigns: [changeset: nil]}
  end

  # Do not log in the <%= schema.singular %> after reset password to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def handle_event("reset_password", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    case <%= inspect context.alias %>.reset_<%= schema.singular %>_password(socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"<%= schema.route_prefix %>/log_in")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"<%= schema.singular %>" => <%= schema.singular %>_params}, socket) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(socket.assigns.<%= schema.singular %>, <%= schema.singular %>_params)
    {:noreply, assign(socket, changeset: Map.put(changeset, :action, :validate))}
  end

  defp assign_<%= schema.singular %>_and_token(socket, %{"token" => token}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_reset_password_token(token) do
      assign(socket, <%= schema.singular %>: <%= schema.singular %>, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end
end
