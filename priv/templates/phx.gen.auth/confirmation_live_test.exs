defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>Live.ConfirmationTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  alias <%= inspect context.module %>

  setup do
    %{unconfirmed_<%= schema.singular %>: unconfirmed_<%= schema.singular %>_fixture(), confirmed_<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "Confirm <%= schema.singular %>" do
    test "renders confirmation page for unconfirmed <%= schema.singular %>", %{conn: conn, unconfirmed_<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed <%= schema.singular %>", %{conn: conn, confirmed_<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"<%= schema.singular %>" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "<%= inspect schema.alias %> confirmed successfully"

      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed <%= schema.singular %> in without changing confirmed_at", %{
      conn: conn,
      confirmed_<%= schema.singular %>: <%= schema.singular %>
    } do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")

      form = form(lv, "#login_form", %{"<%= schema.singular %>" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at == <%= schema.singular %>.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"<%= schema.route_prefix %>/log-in/invalid-token")
        |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
