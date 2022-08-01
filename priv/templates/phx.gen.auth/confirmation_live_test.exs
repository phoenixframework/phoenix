defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "Confirm <%= schema.singular %>" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/confirm/some-token")
      assert html =~ "<h1>Confirm account</h1>"
    end

    test "confirms the given token once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      assert get_flash(conn, :info) =~ "User confirmed successfully"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      assert get_flash(conn, :error) =~ "User confirmation link is invalid or it has expired"

      # when logged in
      {:ok, lv, _html} =
        build_conn()
        |> log_in_<%= schema.singular %>(<%= schema.singular %>)
        |> live(~p"<%= schema.route_prefix %>/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert get_flash(conn, :error) =~ "User confirmation link is invalid or it has expired"
      refute <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
    end
  end
end
