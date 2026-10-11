defmodule Phoenix.Integration.CodeGeneration.AppWithSQLite3AdapterAuthHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth + bcrypt" do
    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("app_with_sqlite3_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "lt_auth_html", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :sqlite3
    test "has a passing test suite (--no-live)" do
      with_installer_tmp("app_with_sqlite3_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "lt_auth_html", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
