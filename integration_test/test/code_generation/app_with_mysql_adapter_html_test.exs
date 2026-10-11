defmodule Phoenix.Integration.CodeGeneration.AppWithMySQLAdapterHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_mysql_adapter_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "my_html", ["--database", "mysql"])

        mix_run!(
          ~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/my_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", MyHtmlWeb do
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
