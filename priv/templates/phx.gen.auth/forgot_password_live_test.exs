defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ForgotPasswordLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/reset_password")

      assert html =~ "Forgot your password?"
      assert html =~ "Register</a>"
      assert html =~ "Log in</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(~p"<%= schema.route_prefix %>/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", <%= schema.singular %>: %{"email" => <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", <%= schema.singular %>: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end
end
