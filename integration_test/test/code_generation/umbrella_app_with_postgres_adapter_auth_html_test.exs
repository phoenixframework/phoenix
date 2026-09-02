defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithPostgresAdapterAuthHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth + bcrypt" do
    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("umbrella_app_with_postgres_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_auth_html", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/um_auth_html_web")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), web_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite --no-live" do
      with_installer_tmp("umbrella_app_with_postgres_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_auth_html", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/um_auth_html_web")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), web_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
