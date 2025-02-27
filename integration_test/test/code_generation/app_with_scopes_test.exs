defmodule Phoenix.Integration.CodeGeneration.AppWithScopesTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth" do
    test "generates scope for phx.gen.live" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.live Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
            """,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

                  live "/posts", PostLive.Index, :index
                  live "/posts/new", PostLive.Form, :new
                  live "/posts/:id", PostLive.Show, :show
                  live "/posts/:id/edit", PostLive.Form, :edit
            """
          )
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "generates scope for phx.gen.html" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.html Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
            """,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

                resources "/posts", PostController
            """
          )
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "generates scope for phx.gen.json" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.json Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", ScopesWeb do
              pipe_through [
                :api,
                :fetch_session,
                :fetch_current_scope_for_user,
                :require_authenticated_user
              ]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "custom scope" do
    test "phx.gen.json" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        modify_file(Path.join(app_root_path, "config/config.exs"), fn file ->
          String.replace(file, "import Config", """
          import Config

          config :scopes, :scopes,
            user: [
              default: false,
              module: Scopes.UserScope,
              assign_key: :user_scope,
              access_path: [:u, :id],
              schema_key: :user_id,
              schema_type: :integer,
              schema_migration_type: :bigint,
              schema_table: nil,
              test_data_fixture: Scopes.UserScopeFixtures,
              test_login_helper: :assign_scope
            ]\
          """)
        end)

        mix_run!(~w(phx.gen.json Blog Post posts title:string --scope user), app_root_path)

        File.write!(Path.join(app_root_path, "test/support/fixtures/user_scope_fixtures.ex"), """
        defmodule Scopes.UserScopeFixtures do
          alias Scopes.UserScope

          def user_scope_fixture(id \\\\ System.unique_integer()) do
            %UserScope{u: %{id: id}}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "test/support/conn_case.ex"), fn file ->
          inject_before_final_end(file, """

            def assign_scope(%{conn: conn}) do
              id = System.unique_integer()
              scope = Scopes.UserScopeFixtures.user_scope_fixture(id)

              conn =
                conn
                |> Phoenix.ConnTest.init_test_session(%{})
                |> Plug.Conn.put_session(:user_id, id)

              %{conn: conn, scope: scope}
            end
          """)
        end)

        File.write!(Path.join(app_root_path, "lib/scopes/user_scope.ex"), """
        defmodule Scopes.UserScope do
          defstruct u: nil

          def new(attrs) do
            %Scopes.UserScope{u: attrs.u}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            defp assign_scope(conn, _opts) do
              conn = Plug.Conn.fetch_session(conn)
              id = Plug.Conn.get_session(conn, :user_id) || raise "no user id found in session"
              assign(conn, :user_scope, Scopes.UserScope.new(%{u: %{id: id}}))
            end

            scope "/api", ScopesWeb do
              pipe_through [:api, :assign_scope]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
