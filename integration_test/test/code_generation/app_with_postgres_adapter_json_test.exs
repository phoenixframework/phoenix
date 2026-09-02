defmodule Phoenix.Integration.CodeGeneration.AppWithPostgresAdapterJsonTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.json" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_postgres_adapter_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_json")

        mix_run!(
          ~w(phx.gen.json Blog Post posts title:unique body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", PgJsonWeb do
              pipe_through [:api]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("app_with_postgres_adapter_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_json")

        mix_run!(
          ~w(phx.gen.json Blog Post posts title:unique body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", PgJsonWeb do
              pipe_through [:api]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
