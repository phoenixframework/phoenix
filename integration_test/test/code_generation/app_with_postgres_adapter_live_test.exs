defmodule Phoenix.Integration.CodeGeneration.AppWithPostgresAdapterLiveTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.live" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_postgres_adapter_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_live", ["--live"])

        mix_run!(
          ~w(phx.gen.live Blog Post posts title:unique body:string p:boolean s:enum:a:b:c),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_live_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PgLiveWeb do
              pipe_through [:browser]

              live "/posts", PostLive.Index, :index
              live "/posts/new", PostLive.Form, :new
              live "/posts/:id", PostLive.Show, :show
              live "/posts/:id/edit", PostLive.Form, :edit
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("app_with_postgres_adapter_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_live", ["--live"])

        mix_run!(
          ~w(phx.gen.live Blog Post posts title body:string public:boolean status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/pg_live_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PgLiveWeb do
              pipe_through [:browser]

              live "/posts", PostLive.Index, :index
              live "/posts/new", PostLive.Form, :new
              live "/posts/:id", PostLive.Show, :show
              live "/posts/:id/edit", PostLive.Form, :edit
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
