defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>
  alias <%= inspect auth_module %><%= if live? do %>

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password-updated"} = params) do
    conn
    |> put_session(:<%= schema.singular %>_return_to, ~p"<%= schema.route_prefix %>/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}, info) do
    %{"email" => email, "password" => password} = <%= schema.singular %>_params
    remember_me = Map.get(<%= schema.singular %>_params, "remember_me", false)

    case <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      <%= if totp? do %>%<%= inspect schema.alias %>{totp_secret: nil} = <%= schema.singular %> ->
        conn
        |> put_flash(:info, info)
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      %<%= inspect schema.alias %>{id: <%= schema.singular %>_id} ->
        conn
        |> put_session(:unauthenticated_<%= schema.singular %>_id, <%= schema.singular %>_id)
        |> put_flash(:remember_me, remember_me)
        |> redirect(to: ~p"<%= schema.route_prefix %>/2fa")

      <% else %>%<%= inspect schema.alias %>{} = <%= schema.singular %> ->
        conn
        |> put_flash(:info, info)
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      <% end %>nil ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> put_flash(:remember_me, remember_me)
        |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
	  end
	end<% else %>

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"email" => email, "password" => password} = <%= schema.singular %>_params

    case <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      <%= if totp? do %>%<%= inspect schema.alias %>{totp_secret: nil} = <%= schema.singular %> ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      %<%= inspect schema.alias %>{id: <%= schema.singular %>_id} ->
        conn
        |> put_session(:unauthenticated_<%= schema.singular %>_id, <%= schema.singular %>_id)
        |> redirect(to: ~p"<%= schema.route_prefix %>/2fa")

      <% else %>%<%= inspect schema.alias %>{} = <%= schema.singular %> ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      <% end %>nil ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        render(conn, :new, error_message: "Invalid email or password")
	  end
	end<% end %>

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()
  end
end
