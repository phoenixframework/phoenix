defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationInstructionsLiveTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %><%= schema.repo_alias %>

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"<%= schema.route_prefix %>/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "confirm"
    end

    test "does not send confirmation token if <%= schema.singular %> is confirmed", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      Repo.update!(<%= inspect context.alias %>.<%= inspect schema.alias %>.confirm_changeset(<%= schema.singular %>))

      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: <%= schema.singular %>.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"<%= schema.route_prefix %>/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", <%= schema.singular %>: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end
end
