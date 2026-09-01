defmodule Phoenix.Integration.CodeGeneration.AppWithPostgresAdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "new with postgres adapter" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("app_with_postgres_adapter", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_app")

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("app_with_postgres_adapter", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "pg_app")

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
