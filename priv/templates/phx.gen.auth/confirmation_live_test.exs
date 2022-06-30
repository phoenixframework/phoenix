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
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, "some-token"))
      assert html =~ "<h1>Confirm account</h1>"
    end

    test "confirms the given token once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, token))

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
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, token))

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
        |> live(Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, token))

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, "invalid-token"))

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :error) =~ "User confirmation link is invalid or it has expired"
      refute <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
    end
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :new))
      assert html =~ "<h1>Resend confirmation instructions</h1>"
    end

    test "sends a new confirmation token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :new))

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "confirm"
    end

    test "does not send confirmation token if <%= schema.singular %> is confirmed", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      Repo.update!(<%= inspect context.alias %>.<%= inspect schema.alias %>.confirm_changeset(<%= schema.singular %>))

      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :new))

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :new))

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end
end
