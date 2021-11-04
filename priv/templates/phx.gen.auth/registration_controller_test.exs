defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import <%= inspect context.module %>Fixtures

  describe "GET <%= web_path_prefix %>/<%= schema.plural %>/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture()) |> get(Routes.<%= schema.route_helper %>_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST <%= web_path_prefix %>/<%= schema.plural %>/register" do
    @tag :capture_log
    test "creates account and logs the <%= schema.singular %> in", %{conn: conn} do
      email = unique_<%= schema.singular %>_email()

      conn =
        post(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :create), %{
          "<%= schema.singular %>" => valid_<%= schema.singular %>_attributes(email: email)
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
