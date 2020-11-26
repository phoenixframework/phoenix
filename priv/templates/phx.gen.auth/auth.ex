defmodule <%= inspect auth_module %> do
  import Plug.Conn
  import Phoenix.Controller

  alias <%= inspect context.module %>
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in <%= inspect schema.alias %>Token.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_<%= web_app_name %>_<%= schema.singular %>_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the <%= schema.singular %> in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_<%= schema.singular %>(conn, <%= schema.singular %>, params \\ %{}) do
    token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
    <%= schema.singular %>_return_to = get_session(conn, :<%= schema.singular %>_return_to)

    conn
    |> renew_session()
    |> put_session(:<%= schema.singular %>_token, token)
    |> put_session(:live_socket_id, "<%= schema.plural %>_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: <%= schema.singular %>_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the <%= schema.singular %> out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_<%= schema.singular %>(conn) do
    <%= schema.singular %>_token = get_session(conn, :<%= schema.singular %>_token)
    <%= schema.singular %>_token && <%= inspect context.alias %>.delete_session_token(<%= schema.singular %>_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      <%= inspect(endpoint_module) %>.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the <%= schema.singular %> by looking into the session
  and remember me token.
  """
  def fetch_current_<%= schema.singular %>(conn, _opts) do
    {<%= schema.singular %>_token, conn} = ensure_<%= schema.singular %>_token(conn)
    <%= schema.singular %> = <%= schema.singular %>_token && <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    assign(conn, :current_<%= schema.singular %>, <%= schema.singular %>)
  end

  defp ensure_<%= schema.singular %>_token(conn) do
    if <%= schema.singular %>_token = get_session(conn, :<%= schema.singular %>_token) do
      {<%= schema.singular %>_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if <%= schema.singular %>_token = conn.cookies[@remember_me_cookie] do
        {<%= schema.singular %>_token, put_session(conn, :<%= schema.singular %>_token, <%= schema.singular %>_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the <%= schema.singular %> to not be authenticated.
  """
  def redirect_if_<%= schema.singular %>_is_authenticated(conn, _opts) do
    if conn.assigns[:current_<%= schema.singular %>] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the <%= schema.singular %> to be authenticated.

  If you want to enforce the <%= schema.singular %> email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_<%= schema.singular %>(conn, _opts) do
    if conn.assigns[:current_<%= schema.singular %>] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Routes.<%= schema.route_helper %>_session_path(conn, :new))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :<%= schema.singular %>_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end
