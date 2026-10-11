defmodule Phoenix.Integration.CodeGeneration.AppWithSQLite3AdapterJsonTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.json" do
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_sqlite3_adapter_json", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "lt_json", ["--database", "sqlite3"])

        mix_run!(
          ~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/lt_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", LtJsonWeb do
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
