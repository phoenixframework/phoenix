defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.LoginTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "Log in"
      assert html =~ "Register"
      assert html =~ "Log in with email"
    end
  end

  describe "<%= schema.singular %> login - magic link" do
    test "sends magic link email when <%= schema.singular %> exists", %{conn: conn} do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", <%= schema.singular %>: %{email: <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "If your email is in our system"

      assert <%= inspect schema.repo %>.get_by!(<%= inspect context.module %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context ==
               "login"
    end

    test "does not disclose if <%= schema.singular %> is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", <%= schema.singular %>: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "<%= schema.singular %> login - password" do
    test "redirects if <%= schema.singular %> logs in with valid credentials", %{conn: conn} do
      <%= schema.singular %> = <%= schema.singular %>_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      form =
        form(lv, "#login_form_password",
          <%= schema.singular %>: %{email: <%= schema.singular %>.email, password: valid_<%= schema.singular %>_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      form =
        form(lv, "#login_form_password", <%= schema.singular %>: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/register")

      assert login_html =~ "Register"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      %{<%= schema.singular %>: <%= schema.singular %>, conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>)}
    end

    test "shows login page with email filled in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert html =~
               ~s(<input type="email" name="<%= schema.singular %>[email]" id="login_form_magic_email" value="#{<%= schema.singular %>.email}")
    end
  end
end
