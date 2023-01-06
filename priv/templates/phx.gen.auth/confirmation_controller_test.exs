defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>
  import <%= inspect context.module %>Fixtures

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "GET <%= schema.route_prefix %>/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/confirm")
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST <%= schema.route_prefix %>/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/confirm", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "confirm"
    end

    test "does not send confirmation token if <%= schema.human_singular %> is confirmed", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      Repo.update!(<%= inspect context.alias %>.<%= inspect schema.alias %>.confirm_changeset(<%= schema.singular %>))

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/confirm", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/confirm", %{
          "<%= schema.singular %>" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end

  describe "GET <%= schema.route_prefix %>/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      token_path = ~p"<%= schema.route_prefix %>/confirm/some-token"
      conn = get(conn, token_path)
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      assert response =~ "action=\"#{token_path}\""
    end
  end

  describe "POST <%= schema.route_prefix %>/confirm/:token" do
    test "confirms the given token once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      conn = post(conn, ~p"<%= schema.route_prefix %>/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "<%= schema.human_singular %> confirmed successfully"

      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []

      # When not logged in
      conn = post(conn, ~p"<%= schema.route_prefix %>/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "<%= schema.human_singular %> confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_<%= schema.singular %>(<%= schema.singular %>)
        |> post(~p"<%= schema.route_prefix %>/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = post(conn, ~p"<%= schema.route_prefix %>/confirm/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "<%= schema.human_singular %> confirmation link is invalid or it has expired"

      refute <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
    end
  end
end
