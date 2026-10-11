defmodule Phoenix.Integration.CodeGeneration.AppWithScopesLiveTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth" do
    @tag database: :postgresql
    test "generates scope for phx.gen.live" do
      with_installer_tmp("scopes_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "sc_live")

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        adjust_migration_timestamps(app_root_path)

        mix_run!(~w(phx.gen.live Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/sc_live_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
            """,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

                  live "/posts", PostLive.Index, :index
                  live "/posts/new", PostLive.Form, :new
                  live "/posts/:id", PostLive.Show, :show
                  live "/posts/:id/edit", PostLive.Form, :edit
            """
          )
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
