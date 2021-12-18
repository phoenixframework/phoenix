defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>

  plug :get_<%= schema.singular %>_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"<%= schema.singular %>" => %{"email" => email}}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(
        <%= schema.singular %>,
        &Routes.<%= schema.route_helper %>_reset_password_url(conn, :edit, &1)
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: <%= inspect context.alias %>.change_<%= schema.singular %>_password(conn.assigns.<%= schema.singular %>))
  end

  # Do not log in the <%= schema.singular %> after reset password to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def update(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    case <%= inspect context.alias %>.reset_<%= schema.singular %>_password(conn.assigns.<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.<%= schema.route_helper %>_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_<%= schema.singular %>_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_reset_password_token(token) do
      conn |> assign(:<%= schema.singular %>, <%= schema.singular %>) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
