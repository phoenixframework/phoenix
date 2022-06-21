defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  <%= inspect context.module %>Fixtures

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>

  describe "Reset password(email page)" do
    test "renders email page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))

      assert html =~ "<h1>Forgot your password?</h1>"
      assert html =~ "Register</a>"
      assert html =~ "Log in</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset token" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))

      {:ok, conn} =
        lv
        |> form("#reset_password_form", <%= schema.singular %>: %{"email" => <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))

      {:ok, conn} =
        lv
        |> form("#reset_password_form", <%= schema.singular %>: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end

  describe "Reset password(new password page)" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          Accounts.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      %{token: token}
    end

    test "renders reset password with valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, token))

      assert html =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      {:error, {:redirect, redirect}} =
        live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, "invalid"))

      assert redirect == %{
               flash: %{"error" => "Reset password link is invalid or it has expired."},
               to: "/"
             }
    end
  end

  describe "Reset password" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      %{token: token, <%= schema.singular %>: <%= schema.singular %>}
    end

    test "resets password once", %{conn: conn, token: token, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, token))

      {:ok, conn} =
        lv
        |> form("#reset_password_form",
          <%= schema.singular %>: %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, Routes.<%= schema.singular %>_login_path(conn, :new))

      refute get_session(conn, :<%= schema.singular %>_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_email_and_password(<%= schema.singular %>.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, token))

      result =
        lv
        |> form("#reset_password_form",
          <%= schema.singular %>: %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        )
        |> render_submit()

      assert result =~ "<h1>Reset password</h1>"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Log in')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/log_in")

      assert conn.resp_body =~ "<h1>Log in</h1>"
    end

    test "redirects to password reset page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Register')})
        |> render_click()
        |> follow_redirect(conn, "/<%= schema.singular %>s/register")

      assert conn.resp_body =~ "<h1>Register</h1>"
    end
  end
end
