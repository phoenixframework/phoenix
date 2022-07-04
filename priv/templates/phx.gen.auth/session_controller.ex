defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect auth_module %><%= if live? do %>

  def login_register(conn, params) do
    do_login(conn, params, "Account created successfully!")
  end

  def login_settings(conn, params) do
    conn
    |> put_session(:<%= schema.singular %>_return_to, Routes.<%= schema.singular %>_settings_path(conn, :edit))
    |> do_login(params, "Settings updated")
  end

  def login(conn, params) do
    do_login(conn, params, "Welcome back!")
  end

  defp do_login(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}, info) do
    %{"email" => email, "password" => password} = <%= schema.singular %>_params

    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: Routes.<%= schema.route_helper %>_login_path(conn, :new))
    end
  end<% else %>

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"email" => email, "password" => password} = <%= schema.singular %>_params

    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(conn, <%= schema.singular %>, <%= schema.singular %>_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end<% end %>

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()
  end
end
