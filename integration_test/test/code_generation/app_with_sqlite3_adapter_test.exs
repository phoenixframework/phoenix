defmodule Phoenix.Integration.CodeGeneration.AppWithSQLite3AdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_sqlite3_app", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_sqlite3_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultSqlite3AppWeb do
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
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_sqlite3_app", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_sqlite3_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", DefaultSqlite3AppWeb do
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
    @tag database: :sqlite3
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_sqlite3_app", ["--database", "sqlite3", "--live"])

        mix_run!(~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_sqlite3_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultSqlite3AppWeb do
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

  describe "phx.gen.auth + bcrypt" do
    test "has no compilation or formatter warnings (--live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :sqlite3
    test "has a passing test suite (--live)" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "default_app", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "has a passing test suite (--no-live)" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "default_app", ["--database", "sqlite3"])

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
