defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  alias <%= inspect context.module %>
  alias <%= inspect schema.repo %>
  import <%= inspect context.module %>Fixtures

  setup do
    %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
  end

  describe "GET /<%= schema.plural %>/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /<%= schema.plural %>/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "confirm"
    end

    test "does not send confirmation token if <%= schema.human_singular %> is confirmed", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      Repo.update!(<%= inspect context.alias %>.<%= inspect schema.alias %>.confirm_changeset(<%= schema.singular %>))

      conn =
        post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :create), %{
          "<%= schema.singular %>" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []
    end
  end

  describe "GET /<%= schema.plural %>/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :edit, "some-token"))
      response = html_response(conn, 200)
      assert response =~ "<h1>Confirm account</h1>"

      form_action = Routes.<%= schema.route_helper %>_confirmation_path(conn, :update, "some-token")
      assert response =~ "action=\"#{form_action}\""
    end
  end

  describe "POST /<%= schema.plural %>/confirm/:token" do
    test "confirms the given token once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      conn = post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "<%= schema.human_singular %> confirmed successfully"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Repo.all(<%= inspect context.alias %>.<%= inspect schema.alias %>Token) == []

      # When not logged in
      conn = post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "<%= schema.human_singular %> confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_<%= schema.singular %>(<%= schema.singular %>)
        |> post(Routes.<%= schema.route_helper %>_confirmation_path(conn, :update, token))

      assert redirected_to(conn) == "/"
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = post(conn, Routes.<%= schema.route_helper %>_confirmation_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "<%= schema.human_singular %> confirmation link is invalid or it has expired"
      refute <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at
    end
  end
end
