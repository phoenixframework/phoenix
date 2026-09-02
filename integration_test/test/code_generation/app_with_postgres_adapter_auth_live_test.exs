defmodule Phoenix.Integration.CodeGeneration.AppWithPostgresAdapterAuthLiveTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth + bcrypt" do
    test "has no compilation or formatter warnings (--live)" do
      with_installer_tmp("app_with_postgres_adapter_auth_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_auth_live")

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite (--live)" do
      with_installer_tmp("app_with_postgres_adapter_auth_live", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_auth_live")

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
