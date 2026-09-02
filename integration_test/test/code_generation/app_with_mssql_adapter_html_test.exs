defmodule Phoenix.Integration.CodeGeneration.AppWithMSSQLAdapterHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :mssql
    test "has a passing test suite" do
      with_installer_tmp("app_with_mssql_adapter_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "ms_html", ["--database", "mssql"])

        mix_run!(
          ~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/ms_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", MsHtmlWeb do
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
