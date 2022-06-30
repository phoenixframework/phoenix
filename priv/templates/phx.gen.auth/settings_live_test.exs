defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SettingsLiveTest do
  use <%= inspect context.web_module %>.ConnCase

  alias <%= inspect context.module %>
  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_<%= schema.singular %>(<%= schema.singular %>_fixture())
        |> live(Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      assert html =~ "<h1>Settings</h1>"
      assert html =~ "<h3>Change email</h3>"
      assert html =~ "<h3>Change password</h3>"
    end

    test "redirects if <%= schema.singular %> is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      assert {:redirect, %{to: "/<%= schema.plural %>/log_in" = _to, flash: flash}} = redirect
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_<%= schema.singular %>_password()
      <%= schema.singular %> = <%= schema.singular %>_fixture(%{password: password})
      %{conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>), <%= schema.singular %>: <%= schema.singular %>, password: password}
    end

    test "updates the <%= schema.singular %> email", %{conn: conn, password: password, <%= schema.singular %>: <%= schema.singular %>} do
      new_email = unique_<%= schema.singular %>_email()

      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "<%= schema.singular %>" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(<%= schema.singular %>.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "<%= schema.singular %>" => %{"email" => "with spaces"}
        })

      assert result =~ "<h1>Settings</h1>"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "<%= schema.singular %>" => %{"email" => <%= schema.singular %>.email}
        })
        |> render_submit()

      assert result =~ "<h1>Settings</h1>"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_<%= schema.singular %>_password()
      <%= schema.singular %> = <%= schema.singular %>_fixture(%{password: password})
      %{conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>), <%= schema.singular %>: <%= schema.singular %>, password: password}
    end

    test "updates the <%= schema.singular %> password", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>, password: password} do
      new_password = valid_<%= schema.singular %>_password()

      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "<%= schema.singular %>" => %{
            "password" => new_password,
            "password_confirmation" => new_password
          },
          _method: "put"
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == Routes.<%= schema.route_helper %>_settings_path(conn, :edit)
      assert get_session(new_password_conn, :<%= schema.singular %>_token) != get_session(conn, :<%= schema.singular %>_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "<%= schema.singular %>" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "<h1>Settings</h1>"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :edit))

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "<%= schema.singular %>" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "<h1>Settings</h1>"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      email = unique_<%= schema.singular %>_email()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_update_email_instructions(%{<%= schema.singular %> | email: email}, <%= schema.singular %>.email, url)
        end)

      %{conn: log_in_<%= schema.singular %>(conn, <%= schema.singular %>), token: token, email: email, <%= schema.singular %>: <%= schema.singular %>}
    end

    test "updates the <%= schema.singular %> email once", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>, token: token, email: email} do
      {:error, redirect} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :confirm_email, token))

      assert {:live_redirect, %{flash: flash, to: "/<%= schema.plural %>/settings"}} = redirect
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(<%= schema.singular %>.email)
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :confirm_email, token))
      assert {:live_redirect, %{flash: flash, to: "/<%= schema.plural %>/settings"}} = redirect
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:error, redirect} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :confirm_email, "oops"))
      assert {:live_redirect, %{flash: flash, to: "/<%= schema.plural %>/settings"}} = redirect
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(<%= schema.singular %>.email)
    end

    test "redirects if <%= schema.singular %> is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, Routes.<%= schema.route_helper %>_settings_path(conn, :confirm_email, token))
      assert {:redirect, %{flash: flash, to: "/<%= schema.plural %>/log_in"}} = redirect
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
