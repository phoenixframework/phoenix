defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithPostgresAdapterJsonTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.json" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_postgres_adapter_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_json", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/um_json_web")

        mix_run!(
          ~w(phx.gen.json Blog Post posts title:unique body:string status:enum:unpublished:published:deleted),
          web_root_path
        )

        modify_file(Path.join(web_root_path, "lib/um_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", UmJsonWeb do
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
      with_installer_tmp("umbrella_app_with_postgres_adapter_json", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_json", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/um_json_web")

        mix_run!(
          ~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted),
          web_root_path
        )

        modify_file(Path.join(web_root_path, "lib/um_json_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", UmJsonWeb do
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
