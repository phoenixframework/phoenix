defmodule Phoenix.Integration.CodeGeneration.AppWithScopesHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth" do
    @tag database: :postgresql
    test "generates scope for phx.gen.html" do
      with_installer_tmp("scopes_html", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "sc_html")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        adjust_migration_timestamps(app_root_path)

        mix_run!(~w(phx.gen.html Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/sc_html_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
            """,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

                resources "/posts", PostController
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
