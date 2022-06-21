defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LoginLive" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_login_path(conn, :new))

      assert html =~ "<h1>Log in</h1>"
      assert html =~ "Register</a>"
      assert html =~ "Forgot your password?</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(Routes.<%= schema.route_helper %>_login_path(conn, :new))
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "<%= schema.singular %> login" do
    test "redirects if <%= schema.singular %> login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      <%= schema.singular %> = <%= schema.singular %>_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_login_path(conn, :new))

      form =
        form(lv, "#login_form", <%= schema.singular %>: %{email: <%= schema.singular %>.email, password: password, remember_me: true})

      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == "/"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_login_path(conn, :new))

      form =
        form(lv, "#login_form",
          <%= schema.singular %>: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert get_flash(conn, :error) == "Invalid email or password"

      assert redirected_to(conn) == "/<%= schema.plural %>/log_in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_login_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Register')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/register")

      assert conn.resp_body =~ "<h1>Register</h1>"
    end

    test "redirects to password reset page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_login_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Forgot your password?')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/reset_password")

      assert conn.resp_body =~ "<h1>Forgot your password?</h1>"
    end
  end
end
