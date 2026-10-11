defmodule Phoenix.Integration.CodeGeneration.AppWithSQLite3AdapterLiveTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.live" do
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_sqlite3_adapter_live", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "lt_live", [
            "--database",
            "sqlite3",
            "--live"
          ])

        mix_run!(
          ~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/lt_live_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", LtLiveWeb do
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
