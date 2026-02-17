defmodule <%= inspect auth_module %>Test do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  <%= if live? do %>alias Phoenix.LiveView
  <% end %>alias <%= inspect context.module %>
  alias <%= inspect context.module %>.<%= inspect scope_config.scope.alias %>
  alias <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Auth

  import <%= inspect context.module %>Fixtures

  @remember_me_cookie "_<%= web_app_name %>_<%= schema.singular %>_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, <%= inspect endpoint_module %>.config(:secret_key_base))
      |> init_test_session(%{})

    %{<%= schema.singular %>: %{<%= schema.singular %>_fixture() | authenticated_at: <%= datetime_now %>}, conn: conn}
  end

  describe "log_in_<%= schema.singular %>/3" do
    test "stores the <%= schema.singular %> token in the session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(conn, <%= schema.singular %>)
      assert token = get_session(conn, :<%= schema.singular %>_token)<%= if live? do %>
      assert get_session(conn, :live_socket_id) == "<%= schema.plural %>_sessions:#{Base.url_encode64(token)}"<% end %>
      assert redirected_to(conn) == ~p"/"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> put_session(:to_be_removed, "value") |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)
      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
        |> put_session(:to_be_removed, "value")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when <%= schema.singular %> does not match when re-authenticating", %{
      conn: conn,
      <%= schema.singular %>: <%= schema.singular %>
    } do
      other_<%= schema.singular %> = <%= schema.singular %>_fixture()

      conn =
        conn
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(other_<%= schema.singular %>))
        |> put_session(:to_be_removed, "value")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> put_session(:<%= schema.singular %>_return_to, "/hello") |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})
      assert get_session(conn, :<%= schema.singular %>_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :<%= schema.singular %>_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :<%= schema.singular %>_token)
      assert max_age == @remember_me_cookie_max_age
    end<%= if live? do %>

    test "redirects to settings when <%= schema.singular %> is already logged in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/settings"
    end<% end %>

    test "writes a cookie if remember_me was set in previous session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})
      assert get_session(conn, :<%= schema.singular %>_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :<%= schema.singular %>_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, <%= inspect endpoint_module %>.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{<%= schema.singular %>_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :<%= schema.singular %>_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :<%= schema.singular %>_remember_me) == true
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
      assert redirected_to(conn) == ~p"/"
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end

    <%= if live? do %>test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "<%= schema.plural %>_sessions:abcdef-token"
      <%= inspect(endpoint_module) %>.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> <%= inspect(schema.alias) %>Auth.log_out_<%= schema.singular %>()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    <% end %>test "works even if <%= schema.singular %> is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()
      refute get_session(conn, :<%= schema.singular %>_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>/2" do
    test "authenticates <%= schema.singular %> from session", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

      conn =
        conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>([])

      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.id == <%= schema.singular %>.id
      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.authenticated_at == <%= schema.singular %>.authenticated_at
      assert get_session(conn, :<%= schema.singular %>_token) == <%= schema.singular %>_token
    end

    test "authenticates <%= schema.singular %> from cookies", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      logged_in_conn =
        conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})

      <%= schema.singular %>_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>([])

      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.id == <%= schema.singular %>.id
      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.authenticated_at == <%= schema.singular %>.authenticated_at
      assert get_session(conn, :<%= schema.singular %>_token) == <%= schema.singular %>_token
      assert get_session(conn, :<%= schema.singular %>_remember_me)<%= if live? do %>

      assert get_session(conn, :live_socket_id) ==
               "<%= schema.plural %>_sessions:#{Base.url_encode64(<%= schema.singular %>_token)}"<% end %>
    end

    test "does not authenticate if data is missing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      conn = <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>(conn, [])
      refute get_session(conn, :<%= schema.singular %>_token)
      refute conn.assigns.<%= scope_config.scope.assign_key %>
    end

    test "reissues a new token after a few days and refreshes cookie", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      logged_in_conn =
        conn |> fetch_cookies() |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_<%= schema.singular %>_token(token, -10, :day)
      {<%= schema.singular %>, _} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)

      conn =
        conn
        |> put_session(:<%= schema.singular %>_token, token)
        |> put_session(:<%= schema.singular %>_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>([])

      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.id == <%= schema.singular %>.id
      assert conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.authenticated_at == <%= schema.singular %>.authenticated_at
      assert new_token = get_session(conn, :<%= schema.singular %>_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  <%= if live? do %>describe "on_mount :mount_<%= scope_config.scope.assign_key %>" do
    setup %{conn: conn} do
      %{conn: <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>(conn, [])}
    end

    test "assigns <%= scope_config.scope.assign_key %> based on a valid <%= schema.singular %>_token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      {:cont, updated_socket} =
        <%= inspect schema.alias %>Auth.on_mount(:mount_<%= scope_config.scope.assign_key %>, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "assigns nil to <%= scope_config.scope.assign_key %> assign if there isn't a valid <%= schema.singular %>_token", %{conn: conn} do
      <%= schema.singular %>_token = "invalid_token"
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      {:cont, updated_socket} =
        <%= inspect schema.alias %>Auth.on_mount(:mount_<%= scope_config.scope.assign_key %>, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.<%= scope_config.scope.assign_key %> == nil
    end

    test "assigns nil to <%= scope_config.scope.assign_key %> assign if there isn't a <%= schema.singular %>_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        <%= inspect schema.alias %>Auth.on_mount(:mount_<%= scope_config.scope.assign_key %>, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.<%= scope_config.scope.assign_key %> == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates <%= scope_config.scope.assign_key %> based on a valid <%= schema.singular %>_token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      {:cont, updated_socket} =
        <%= inspect schema.alias %>Auth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "redirects to login page if there isn't a valid <%= schema.singular %>_token", %{conn: conn} do
      <%= schema.singular %>_token = "invalid_token"
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: <%= inspect context.web_module %>.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = <%= inspect schema.alias %>Auth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.<%= scope_config.scope.assign_key %> == nil
    end

    test "redirects to login page if there isn't a <%= schema.singular %>_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: <%= inspect context.web_module %>.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = <%= inspect schema.alias %>Auth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.<%= scope_config.scope.assign_key %> == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows <%= schema.plural %> that have authenticated in the last 10 minutes", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: <%= inspect(endpoint_module) %>,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               <%= inspect schema.alias %>Auth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      eleven_minutes_ago = <%= datetime_now %> |> <%= inspect datetime_module %>.add(-11, :minute)
      <%= schema.singular %> = %{<%= schema.singular %> | authenticated_at: eleven_minutes_ago}
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      {<%= schema.singular %>, token_inserted_at} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
      assert <%= inspect datetime_module %>.compare(token_inserted_at, <%= schema.singular %>.authenticated_at) == :gt
      session = conn |> put_session(:<%= schema.singular %>_token, <%= schema.singular %>_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: <%= inspect context.web_module %>.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               <%= inspect schema.alias %>Auth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end<% else %>describe "require_sudo_mode/2" do
    test "allows <%= schema.plural %> that have authenticated in the last 10 minutes", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> fetch_flash()
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
        |> <%= inspect schema.alias %>Auth.require_sudo_mode([])

      refute conn.halted
      refute conn.status
    end

    test "redirects when authentication is too old", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      eleven_minutes_ago = <%= datetime_now %> |> <%= inspect datetime_module %>.add(-11, :minute)
      <%= schema.singular %> = %{<%= schema.singular %> | authenticated_at: eleven_minutes_ago}
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      {<%= schema.singular %>, token_inserted_at} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
      assert <%= inspect datetime_module %>.compare(token_inserted_at, <%= schema.singular %>.authenticated_at) == :gt

      conn =
        conn
        |> fetch_flash()
        |> assign(:<%= scope_config.scope.assign_key %>, Scope.for_<%= schema.singular %>(<%= schema.singular %>))
        |> <%= inspect schema.alias %>Auth.require_sudo_mode([])

      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must re-authenticate to access this page."
    end
  end

  describe "redirect_if_<%= schema.singular %>_is_authenticated/2" do
    setup %{conn: conn} do
      %{conn: <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>(conn, [])}
    end

    test "redirects if <%= schema.singular %> is authenticated", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
        |> <%= inspect schema.alias %>Auth.redirect_if_<%= schema.singular %>_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if <%= schema.singular %> is not authenticated", %{conn: conn} do
      conn = <%= inspect schema.alias %>Auth.redirect_if_<%= schema.singular %>_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end<% end %>

  describe "require_authenticated_<%= schema.singular %>/2" do
    setup %{conn: conn} do
      %{conn: <%= inspect schema.alias %>Auth.fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>(conn, [])}
    end

    test "redirects if <%= schema.singular %> is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])
      assert conn.halted

      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
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
      conn =
        conn
        |> assign(:<%= scope_config.scope.assign_key %>, <%= inspect scope_config.scope.alias %>.for_<%= schema.singular %>(<%= schema.singular %>))
        |> <%= inspect schema.alias %>Auth.require_authenticated_<%= schema.singular %>([])

      refute conn.halted
      refute conn.status
    end
  end<%= if live? do %>

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        <%= inspect context.web_module %>.Endpoint.subscribe("<%= schema.plural %>_sessions:#{Base.url_encode64(token)}")
      end

      <%= inspect schema.alias %>Auth.disconnect_sessions(tokens)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "<%= schema.plural %>_sessions:dG9rZW4x"
      }

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "<%= schema.plural %>_sessions:dG9rZW4y"
      }
    end
  end<% end %>
end
