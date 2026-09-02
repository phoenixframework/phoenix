defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithPostgresAdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "new umbrella app" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_postgres_adapter", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "um_app", ["--umbrella"])

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("umbrella_app_with_postgres_adapter", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "um_app", ["--umbrella"])

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
