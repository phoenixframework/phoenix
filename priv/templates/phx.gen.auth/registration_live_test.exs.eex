defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.RegistrationTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(~p"<%= schema.route_prefix %>/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(<%= schema.singular %>: %{"email" => "with spaces"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register <%= schema.singular %>" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      email = unique_<%= schema.singular %>_email()
      form = form(lv, "#registration_form", <%= schema.singular %>: valid_<%= schema.singular %>_attributes(email: email))

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~
               ~r/An email was sent to .*, please access it to confirm your account/
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      <%= schema.singular %> = <%= schema.singular %>_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          <%= schema.singular %>: %{"email" => <%= schema.singular %>.email}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert login_html =~ "Log in"
    end
  end
end
