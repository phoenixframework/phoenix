defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionControllerTest do
  use <%= inspect context.web_module %>.ConnCase<%= test_case_options %>

  import <%= inspect context.module %>Fixtures
  alias <%= inspect context.module %>

  setup do
    %{unconfirmed_<%= schema.singular %>: unconfirmed_<%= schema.singular %>_fixture(), <%= schema.singular %>: <%= schema.singular %>_fixture()}
  end<%= if not live? do %>

  describe "GET <%= schema.route_prefix %>/log-in" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/log-in")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"<%= schema.route_prefix %>/register"
      assert response =~ "Log in with email"
    end

    test "renders login page with email filled in (sudo mode)", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      html =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>)
        |> get(~p"<%= schema.route_prefix %>/log-in")
        |> html_response(200)

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert html =~
               ~s(<input type="email" name="<%= schema.singular %>[email]" id="login_form_magic_email" value="#{<%= schema.singular %>.email}")
    end

    test "renders login page (email + password)", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/log-in?mode=password")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"<%= schema.route_prefix %>/register"
      assert response =~ "Log in with email"
    end
  end

  describe "GET <%= schema.route_prefix %>/log-in/:token" do
    test "renders confirmation page for unconfirmed <%= schema.singular %>", %{conn: conn, unconfirmed_<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      conn = get(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
      assert html_response(conn, 200) =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_login_instructions(<%= schema.singular %>, url)
        end)

      conn = get(conn, ~p"<%= schema.route_prefix %>/log-in/#{token}")
      html = html_response(conn, 200)
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.route_prefix %>/log-in/invalid-token")
      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Magic link is invalid or it has expired."
    end
  end<% end %>

  describe "POST <%= schema.route_prefix %>/log-in - email and password" do
    test "logs the <%= schema.singular %> in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %> = set_password(<%= schema.singular %>)

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email, "password" => valid_<%= schema.singular %>_password()}
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ <%= schema.singular %>.email
      assert response =~ ~p"<%= schema.route_prefix %>/settings"
      assert response =~ ~p"<%= schema.route_prefix %>/log-out"
    end

    test "logs the <%= schema.singular %> in with remember me", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %> = set_password(<%= schema.singular %>)

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_<%= web_app_name %>_<%= schema.singular %>_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the <%= schema.singular %> in with return to", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %> = set_password(<%= schema.singular %>)

      conn =
        conn
        |> init_test_session(<%= schema.singular %>_return_to: "/foo/bar")
        |> post(~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{
            "email" => <%= schema.singular %>.email,
            "password" => valid_<%= schema.singular %>_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "<%= if live?, do: "redirects to login page", else: "emits error message" %> with invalid credentials", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in?mode=password", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email, "password" => "invalid_password"}
        })

      <%= if live? do %>assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"<% else %>response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ "Invalid email or password"<% end %>
    end
  end

  describe "POST <%= schema.route_prefix %>/log-in - magic link" do
    <%= if not live? do %>test "sends magic link email when <%= schema.singular %> exists", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert <%= inspect schema.repo %>.get_by!(<%= inspect context.alias %>.<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id).context == "login"
    end

    <% end %>test "logs the <%= schema.singular %> in", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {token, _hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{"token" => token}
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ <%= schema.singular %>.email
      assert response =~ ~p"<%= schema.route_prefix %>/settings"
      assert response =~ ~p"<%= schema.route_prefix %>/log-out"
    end

    test "confirms unconfirmed <%= schema.singular %>", %{conn: conn, unconfirmed_<%= schema.singular %>: <%= schema.singular %>} do
      {token, _hashed_token} = generate_<%= schema.singular %>_magic_link_token(<%= schema.singular %>)
      refute <%= schema.singular %>.confirmed_at

      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :<%= schema.singular %>_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "<%= schema.human_singular %> confirmed successfully."

      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ <%= schema.singular %>.email
      assert response =~ ~p"<%= schema.route_prefix %>/settings"
      assert response =~ ~p"<%= schema.route_prefix %>/log-out"
    end

    test "<%= if live?, do: "redirects to login page", else: "emits error message" %> when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"<%= schema.route_prefix %>/log-in", %{
          "<%= schema.singular %>" => %{"token" => "invalid"}
        })

      <%= if live? do %>assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"<%= schema.route_prefix %>/log-in"<% else %>assert html_response(conn, 200) =~ "The link is invalid or it has expired."<% end %>
    end
  end

  describe "DELETE <%= schema.route_prefix %>/log-out" do
    test "logs the <%= schema.singular %> out", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = conn |> log_in_<%= schema.singular %>(<%= schema.singular %>) |> delete(~p"<%= schema.route_prefix %>/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the <%= schema.singular %> is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"<%= schema.route_prefix %>/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :<%= schema.singular %>_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
