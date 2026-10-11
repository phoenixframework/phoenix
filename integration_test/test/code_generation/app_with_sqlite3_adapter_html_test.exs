defmodule Phoenix.Integration.CodeGeneration.AppWithSQLite3AdapterHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_sqlite3_adapter_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "lt_html", ["--database", "sqlite3"])

        mix_run!(
          ~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/lt_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", LtHtmlWeb do
              pipe_through [:browser]

              resources "/posts", PostController
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
