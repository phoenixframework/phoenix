defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SecondFactorController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>

  plug :fetch_unauthenticated_<%= schema.singular %><%= if live? do %>

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"code" => code} = <%= schema.singular %>_params
    <%= schema.singular %> = conn.assigns.unauthenticated_<%= schema.singular %>

    if <%= schema.singular %> && <%= inspect context.module %>.valid_<%= schema.singular %>_otp?(<%= schema.singular %>, code) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> <%= inspect auth_module %>.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)
    else
      conn
      |> put_flash(:error, "Invalid 2FA code")
      |> redirect(to: ~p"<%= schema.route_prefix %>/2fa")
    end
  end<% else %>

  def new(conn, _params) do
    if conn.assigns.unauthenticated_<%= schema.singular %> do
      render(conn, :new, error_message: nil)
    else
      redirect(conn, to: ~p"<%= schema.route_prefix %>/log_in")
    end
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    %{"code" => code} = <%= schema.singular %>_params
    <%= schema.singular %> = conn.assigns.unauthenticated_<%= schema.singular %>

    if <%= schema.singular %> && <%= inspect context.module %>.valid_<%= schema.singular %>_otp?(<%= schema.singular %>, code) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> <%= inspect auth_module %>.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)
    else
      render(conn, :new, error_message: "Invalid 2FA code")
    end
  end<% end %>

  defp fetch_unauthenticated_<%= schema.singular %>(conn, _opts) do
    if <%= schema.singular %>_id = get_session(conn, :unauthenticated_<%= schema.singular %>_id) do
      <%= schema.singular %> = Accounts.get_<%= schema.singular %>!(<%= schema.singular %>_id)
      assign(conn, :unauthenticated_<%= schema.singular %>, <%= schema.singular %>)
    else
      assign(conn, :unauthenticated_<%= schema.singular %>, nil)
    end
  end
end
