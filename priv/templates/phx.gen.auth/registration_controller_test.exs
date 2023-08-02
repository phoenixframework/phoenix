defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import <%= inspect context.module %>Fixtures

  describe "GET <%= schema.route_prefix %>/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"<%= schema.route_prefix %>/log_in"
      assert response =~ ~p"<%= schema.route_prefix %>/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture()) |> get(~p"<%= schema.route_prefix %>/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST <%= schema.route_prefix %>/register" do
    @tag :capture_log
    test "creates account and logs the <%= schema.singular %> in", %{conn: conn} do
      email = unique_<%= schema.singular %>_email()

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/register", %{
          "<%= schema.singular %>" => valid_<%= schema.singular %>_attributes(email: email)
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ ~p"<%= schema.route_prefix %>/settings"
      assert response =~ ~p"<%= schema.route_prefix %>/log_out"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/register", %{
          "<%= schema.singular %>" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
