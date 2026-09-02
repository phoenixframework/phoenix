defmodule Phoenix.Integration.CodeGeneration.AppWithMySQLAdapterJsonTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.json" do
    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_mysql_adapter_json", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "my_json", ["--database", "mysql"])

        mix_run!(
          ~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/my_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", MyJsonWeb do
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
