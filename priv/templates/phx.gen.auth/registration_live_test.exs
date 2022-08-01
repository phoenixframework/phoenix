defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      assert html =~ "<h1>Register</h1>"
      assert html =~ "Log in</a>"
      assert html =~ "Forgot your password?</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(~p"<%= schema.route_prefix %>/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(<%= schema.singular %>: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "<h1>Register</h1>"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register <%= schema.singular %>" do
    test "creates account and logs the <%= schema.singular %> in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      email = unique_<%= schema.singular %>_email()
      form = form(lv, "#registration_form", <%= schema.singular %>: valid_<%= schema.singular %>_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      <%= schema.singular %> = <%= schema.singular %>_fixture(%{email: "test@email.com"})

      lv
      |> form("#registration_form",
        <%= schema.singular %>: %{"email" => <%= schema.singular %>.email, "password" => "valid_password"}
      )
      |> render_submit() =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Log in')})
        |> render_click()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log_in")

      assert conn.resp_body =~ "<h1>Log in</h1>"
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Forgot your password?')})
        |> render_click()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/reset_password")

      assert conn.resp_body =~ "<h1>Forgot your password?</h1>"
    end
  end
end
