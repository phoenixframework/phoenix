defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationLive" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))

      assert html =~ "<h1>Register</h1>"
      assert html =~ "Log in</a>"
      assert html =~ "Forgot your password?</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(Routes.<%= schema.route_helper %>_registration_path(conn, :new))
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "register <%= schema.singular %>" do
    test "creates account and logs the <%= schema.singular %> in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))

      email = unique_<%= schema.singular %>_email()
      form = form(lv, "#registration_form", <%= schema.singular %>: valid_<%= schema.singular %>_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))

      result =
        lv
        |> form("#registration_form", <%= schema.singular %>: %{"email" => "with spaces", "password" => "too short"})
        |> render_submit()

      assert result =~ "<h1>Register</h1>"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Log in')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/log_in")

      assert conn.resp_body =~ "<h1>Log in</h1>"
    end

    test "redirects to password reset page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_registration_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Forgot your password?')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/reset_password")

      assert conn.resp_body =~ "<h1>Forgot your password?</h1>"
    end
  end
end
