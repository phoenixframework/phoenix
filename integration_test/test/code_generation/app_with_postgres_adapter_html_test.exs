defmodule Phoenix.Integration.CodeGeneration.AppWithPostgresAdapterHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_postgres_adapter_html", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_html")

        mix_run!(
          ~w(phx.gen.html Blog Post posts title:unique body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PgHtmlWeb do
              pipe_through [:browser]

              resources "/posts", PostController
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("app_with_postgres_adapter_html", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_html")

        mix_run!(
          ~w(phx.gen.html Blog Post posts title:unique body:string status:enum:unpublished:published:deleted order:integer:unique),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PgHtmlWeb do
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
