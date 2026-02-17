defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SettingsController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect auth_module %>

  import <%= inspect auth_module %>, only: [require_sudo_mode: 2]

  plug :require_sudo_mode
  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>

    case <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>, <%= schema.singular %>_params) do
      %{valid?: true} = changeset ->
        <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          <%= schema.singular %>.email,
          &url(~p"<%= schema.route_prefix %>/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params
    <%= schema.singular %> = conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>

    case <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, <%= schema.singular %>_params) do
      {:ok, {<%= schema.singular %>, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:<%= schema.singular %>_return_to, ~p"<%= schema.route_prefix %>/settings")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case <%= inspect context.alias %>.update_<%= schema.singular %>_email(conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>, token) do
      {:ok, _<%= schema.singular %>} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    <%= schema.singular %> = conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>

    conn
    |> assign(:email_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_email(<%= schema.singular %>))
    |> assign(:password_changeset, <%= inspect context.alias %>.change_<%= schema.singular %>_password(<%= schema.singular %>))
  end
end
