defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ResetPasswordControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>
  import <%= inspect context.module %>Fixtures

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "GET <%= web_path_prefix %>/<%= schema.plural %>/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST <%= web_path_prefix %>/<%= schema.plural %>/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end

  describe "GET <%= web_path_prefix %>/<%= schema.plural %>/reset_password/:token" do
    setup %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT <%= web_path_prefix %>/<%= schema.plural %>/reset_password/:token" do
    setup %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>, token: token} do
      conn =
        put(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :update, token), %{
          "<%= schema.singular %>" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.<%= schema.route_helper %>_session_path(conn, :new)
      refute get_session(conn, :<%= schema.singular %>_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :update, token), %{
          "<%= schema.singular %>" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Reset password</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.<%= schema.route_helper %>_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
