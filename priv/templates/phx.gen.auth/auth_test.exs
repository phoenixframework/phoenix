defmodule <%= inspect auth_module %>Test do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  alias <%= inspect context.module %>
  alias <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Auth
  import <%= inspect context.module %>Fixtures

  @remember_me_cookie "_<%= web_app_name %>_<%= schema.singular %>_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, <%= inspect endpoint_module %>.config(:secret_key_base))
      |> init_test_session(%{})

    %{<%= schema.singular %>: <%= schema.singular %>_fixture(), conn: conn}
  end

  describe "log_in_<%= schema.singular %>/3" do
    test "stores the <%= schema.singular %> token in the session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(conn, <%= schema.singular %>)
      assert token = get_session(conn, :<%= schema.singular %>_token)
      assert get_session(conn, :live_socket_id) == "<%= schema.plural %>_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> put_session(:to_be_removed, "value") |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> put_session(:<%= schema.singular %>_return_to, "/hello") |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})
      assert get_session(conn, :<%= schema.singular %>_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :<%= schema.singular %>_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_<%= schema.singular %>/1" do
    test "erases session and cookies", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

      conn =
        conn
        |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token)
        |> put_req_cookie(@remember_me_cookie, <%= schema.singular %>_token)
        |> fetch_cookies()
        |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()

      refute get_session(conn, :<%= schema.singular %>_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "<%= schema.plural %>_sessions:abcdef-token"
      <%= inspect(endpoint_module) %>.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> <%= inspect(schema.alias) %>Auth.log_out_<%= schema.singular %>()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if <%= schema.singular %> is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()
      refute get_session(conn, :<%= schema.singular %>_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_<%= schema.singular %>/2" do
    test "authenticates <%= schema.singular %> from session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      conn = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> <%= inspect schema.alias %>Auth.fetch_current_<%= schema.singular %>([])
      assert conn.assigns.current_<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "authenticates <%= schema.singular %> from cookies", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      logged_in_conn =
        conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})

      <%= schema.singular %>_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> <%= inspect schema.alias %>Auth.fetch_current_<%= schema.singular %>([])

      assert get_session(conn, :<%= schema.singular %>_token) == <%= schema.singular %>_token
      assert conn.assigns.current_<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "does not authenticate if data is missing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      conn = <%= inspect schema.alias %>Auth.fetch_current_<%= schema.singular %>(conn, [])
      refute get_session(conn, :<%= schema.singular %>_token)
      refute conn.assigns.current_<%= schema.singular %>
    end
  end

  describe "redirect_if_<%= schema.singular %>_is_authenticated/2" do
    test "redirects if <%= schema.singular %> is authenticated", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> assign(:current_<%= schema.singular %>, <%= schema.singular %>) |> <%= inspect schema.alias %>Auth.redirect_if_<%= schema.singular %>_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if <%= schema.singular %> is not authenticated", %{conn: conn} do
      conn = <%= inspect schema.alias %>Auth.redirect_if_<%= schema.singular %>_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_<%= schema.singular %>/2" do
    test "redirects if <%= schema.singular %> is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])
      assert conn.halted
      assert redirected_to(conn) == Routes.<%= schema.route_helper %>_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])

      assert halted_conn.halted
      assert get_session(halted_conn, :<%= schema.singular %>_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])

      assert halted_conn.halted
      assert get_session(halted_conn, :<%= schema.singular %>_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])

      assert halted_conn.halted
      refute get_session(halted_conn, :<%= schema.singular %>_return_to)
    end

    test "does not redirect if <%= schema.singular %> is authenticated", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> assign(:current_<%= schema.singular %>, <%= schema.singular %>) |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])
      refute conn.halted
      refute conn.status
    end
  end
end
