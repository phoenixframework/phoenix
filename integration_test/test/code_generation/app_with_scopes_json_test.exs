defmodule Phoenix.Integration.CodeGeneration.AppWithScopesJsonTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth" do
    @tag database: :postgresql
    test "generates scope for phx.gen.json" do
      with_installer_tmp("scopes_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "sc_json")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        adjust_migration_timestamps(app_root_path)

        mix_run!(~w(phx.gen.json Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/sc_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", ScJsonWeb do
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
    @tag database: :postgresql
    test "phx.gen.json" do
      with_installer_tmp("scopes_custom_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "sc_json")

        modify_file(Path.join(app_root_path, "config/config.exs"), fn file ->
          String.replace(file, "import Config", """
          import Config

          config :sc_json, :scopes,
            user: [
              default: false,
              module: ScJson.UserScope,
              assign_key: :user_scope,
              access_path: [:u, :id],
              schema_key: :user_id,
              schema_type: :integer,
              schema_migration_type: :bigint,
              schema_table: nil,
              test_data_fixture: ScJson.UserScopeFixtures,
              test_setup_helper: :assign_scope
            ]\
          """)
        end)

        mix_run!(~w(phx.gen.json Blog Post posts title:string --scope user), app_root_path)

        File.write!(Path.join(app_root_path, "test/support/fixtures/user_scope_fixtures.ex"), """
        defmodule ScJson.UserScopeFixtures do
          alias ScJson.UserScope

          def user_scope_fixture(id \\\\ System.unique_integer()) do
            %UserScope{u: %{id: id}}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "test/support/conn_case.ex"), fn file ->
          inject_before_final_end(file, """

            def assign_scope(%{conn: conn}) do
              id = System.unique_integer()
              scope = ScJson.UserScopeFixtures.user_scope_fixture(id)

              conn =
                conn
                |> Phoenix.ConnTest.init_test_session(%{})
                |> Plug.Conn.put_session(:user_id, id)

              %{conn: conn, scope: scope}
            end
          """)
        end)

        File.write!(Path.join(app_root_path, "lib/sc_json/user_scope.ex"), """
        defmodule ScJson.UserScope do
          defstruct u: nil

          def new(attrs) do
            %ScJson.UserScope{u: attrs.u}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "lib/sc_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            defp assign_scope(conn, _opts) do
              conn = Plug.Conn.fetch_session(conn)
              id = Plug.Conn.get_session(conn, :user_id) || raise "no user id found in session"
              assign(conn, :user_scope, ScJson.UserScope.new(%{u: %{id: id}}))
            end

            scope "/api", ScJsonWeb do
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
