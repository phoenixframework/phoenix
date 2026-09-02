defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithPostgresAdapterLiveTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.live" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_postgres_adapter_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_live", ["--umbrella", "--live"])
        web_root_path = Path.join(app_root_path, "apps/um_live_web")

        mix_run!(
          ~w(phx.gen.live Blog Post posts title:unique body:string status:enum:unpublished:published:deleted),
          web_root_path
        )

        modify_file(Path.join(web_root_path, "lib/um_live_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", UmLiveWeb do
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
      with_installer_tmp("umbrella_app_with_postgres_adapter_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_live", ["--umbrella", "--live"])
        web_root_path = Path.join(app_root_path, "apps/um_live_web")

        mix_run!(
          ~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted),
          web_root_path
        )

        modify_file(Path.join(web_root_path, "lib/um_live_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", UmLiveWeb do
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
