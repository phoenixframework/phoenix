defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SettingsController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect auth_module %>

  plug :assign_email_totp_and_password_changesets
  plug :assign_totp_secret_and_url

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    case <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, password, <%= schema.singular %>_params) do
      {:ok, applied_<%= schema.singular %>} ->
        <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(
          applied_<%= schema.singular %>,
          <%= schema.singular %>.email,
          &url(~p"<%= schema.route_prefix %>/settings/confirm_email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")

      {:error, changeset} ->
        render(conn, :edit, email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    case <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, password, <%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:<%= schema.singular %>_return_to, ~p"<%= schema.route_prefix %>/settings")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "enable_totp", "<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"code" => code, "secret" => secret} = <%= schema.singular %>_params
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    {:ok, secret} = Base.decode64(secret)

    case <%= inspect context.alias %>.enable_<%= schema.singular %>_2fa(<%= schema.singular %>, secret, code) do
      {:ok, <%= schema.singular %>} ->
        changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_totp(<%= schema.singular %>)

        conn
        |> put_flash(:info, "2FA enabled successfully.")
        |> assign(:current_<%= schema.singular %>, <%= schema.singular %>)
        |> assign(:totp_changeset, changeset)
        |> render(:edit)

      {:error, changeset} ->
        render(conn, :edit, totp_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "disable_totp", "<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"code" => code, "current_password" => password} = <%= schema.singular %>_params
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    case <%= inspect context.alias %>.disable_<%= schema.singular %>_2fa(<%= schema.singular %>, password, code) do
      {:ok, <%= schema.singular %>} ->
        changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_totp(<%= schema.singular %>)

        conn
        |> put_flash(:info, "2FA disabled successfully.")
        |> assign(:current_<%= schema.singular %>, <%= schema.singular %>)
        |> assign(:totp_changeset, changeset)
        |> render(:edit)

      {:error, changeset} ->
        render(conn, :edit, totp_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case <%= inspect context.alias %>.update_<%= schema.singular %>_email(conn.assigns.current_<%= schema.singular %>, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")
    end
  end

  defp assign_email_totp_and_password_changesets(conn, _opts) do
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    conn
    |> assign(:email_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>))
    |> assign(:password_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>))
    |> assign(:totp_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_totp(<%= schema.singular %>))
  end

  defp assign_totp_secret_and_url(conn, _opts) do
    <%= schema.singular %> = conn.assigns.current_<%= schema.singular %>

    secret = <%= schema.singular %>.totp_secret || NimbleTOTP.secret()
    encoded = Base.encode64(secret)
    url = NimbleTOTP.otpauth_uri("Dummy - #{<%= schema.singular %>.email}", secret, issuer: "Dummy")

    conn
    |> assign(:totp_secret, encoded)
    |> assign(:otp_url, url)
  end
end
