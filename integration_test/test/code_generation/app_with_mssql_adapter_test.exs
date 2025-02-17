defmodule Phoenix.Integration.CodeGeneration.AppWithMSSQLAdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :mssql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mssql_app", ["--database", "mssql"])

        mix_run!(~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mssql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMssqlAppWeb do
              pipe_through [:browser]

              resources "/posts", PostController
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.json" do
    @tag database: :mssql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mssql_app", ["--database", "mssql"])

        mix_run!(~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mssql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", DefaultMssqlAppWeb do
              pipe_through [:api]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.live" do
    @tag database: :mssql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mssql_app", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mssql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMssqlAppWeb do
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

  describe "phx.gen.auth + pbkdf2 + existing context" do
    test "has no compilation or formatter warnings (--live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/phx_blog_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PhxBlogWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/phx_blog_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PhxBlogWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --no-live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mssql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults (--live)", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/phx_blog_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PhxBlogWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    @tag database: :mssql
    test "has a passing test suite (--no-live)" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mssql", "--live"])

        mix_run!(~w(phx.gen.html Accounts Group groups name), app_root_path)

        modify_file(Path.join(app_root_path, "lib/phx_blog_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", PhxBlogWeb do
              pipe_through [:browser]

              resources "/groups", GroupController
            end
          """)
        end)

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib pbkdf2 --merge-with-existing-context --no-live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
