defmodule Phoenix.Integration.CodeGeneration.AppWithMySqlAdapterTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.html" do
    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql"])

        mix_run!(~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMysqlAppWeb do
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
    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql"])

        mix_run!(~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", DefaultMysqlAppWeb do
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
    @tag database: :mysql
    test "has a passing test suite" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "default_mysql_app", ["--database", "mysql", "--live"])

        mix_run!(~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted), app_root_path)

        modify_file(Path.join(app_root_path, "lib/default_mysql_app_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", DefaultMysqlAppWeb do
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

  describe "phx.gen.auth + argon2" do
    test "has no compilation or formatter warnings (--live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mysql", "--binary-id"])

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib argon2 --live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--database", "mysql", "--binary-id"])

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib argon2 --no-live), app_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite (--live)" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "default_app", ["--database", "mysql", "--binary-id"])

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib argon2 --live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    @tag database: :mysql
    test "has a passing test suite (--no-live)" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "default_app", ["--database", "mysql", "--binary-id"])

        mix_run!(~w(phx.gen.auth Accounts User users --hashing-lib argon2 --no-live), app_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
