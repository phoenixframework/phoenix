defmodule Phoenix.Integration.CodeGeneration.AppWithMySQLAdapterScopesTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.live with scope" do
    @tag database: :mysql
    test "has a passing test suite with scoped references" do
      with_installer_tmp("app_with_mysql_adapter_scopes", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "my_scope", ["--database", "mysql", "--live"])

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)

        mix_run!(
          ~w(phx.gen.live Blog Post posts title:string),
          app_root_path
        )

        modify_file(Path.join(app_root_path, "lib/my_scope_web/router.ex"), fn file ->
          String.replace(
            file,
            "live \"/users/settings/confirm-email/:token\", UserLive.Settings, :confirm_email",
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

                  live "/posts", PostLive.Index, :index
                  live "/posts/new", PostLive.Form, :new
                  live "/posts/:id", PostLive.Show, :show
                  live "/posts/:id/edit", PostLive.Form, :edit
            """
          )
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
