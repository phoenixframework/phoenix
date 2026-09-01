defmodule Phoenix.Integration.CodeGeneration.AppWithMSSQLAdapterAuthHtmlTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth + pbkdf2 + existing context" do
    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("app_with_mssql_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "ms_auth_html", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/ms_auth_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", MsAuthHtmlWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(
          ~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --no-live),
          app_root_path
        )

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mssql
    test "has a passing test suite (--no-live)" do
      with_installer_tmp("app_with_mssql_adapter_auth_html", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "ms_auth_html", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/ms_auth_html_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", MsAuthHtmlWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(
          ~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --no-live),
          app_root_path
        )

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
