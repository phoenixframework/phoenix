defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import <%= inspect context.module %>Fixtures

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end<%= if not live? do %>

  describe "GET <%= schema.route_prefix %>/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/log_in")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"/users/register"
      assert response =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> log_in_<%= schema.singular %>(<%= schema.singular %>) |> get(~p"<%= schema.route_prefix %>/log_in")
      assert redirected_to(conn) == ~p"/"
    end
  end<% end %>

  describe "POST <%= schema.route_prefix %>/log_in" do
    test "logs the <%= schema.singular %> in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log_in", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email, "password" => valid_<%= schema.singular %>_password()}
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ <%= schema.singular %>.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log_out"
    end

    test "logs the <%= schema.singular %> in with remember me", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log_in", %{
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_<%= web_app_name %>_<%= schema.singular %>_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the <%= schema.singular %> in with return to", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> init_test_session(<%= schema.singular %>_return_to: "/foo/bar")
        |> post(~p"<%= schema.route_prefix %>/log_in", %{
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end<%= if live? do %>

    test "login following registration", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> post(~p"<%= schema.route_prefix %>/log_in", %{
          "_action" => "registered",
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        conn
        |> post(~p"<%= schema.route_prefix %>/log_in", %{
          "_action" => "password_updated",
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password()
          }
        })

      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log_in", %{
          "<%= schema.singular %>" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log_in"
    end<% else %>

    test "emits error message with invalid credentials", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log_in", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ "Invalid email or password"
    end<% end %>
  end

  describe "DELETE <%= schema.route_prefix %>/log_out" do
    test "logs the <%= schema.singular %> out", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> log_in_<%= schema.singular %>(<%= schema.singular %>) |> delete(~p"<%= schema.route_prefix %>/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the <%= schema.singular %> is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"<%= schema.route_prefix %>/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
