defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithDefaultsTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "new umbrella app" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "phx_blog", ["--umbrella"])

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} =
          generate_phoenix_app(tmp_dir, "umbrella_with_defaults", ["--umbrella"])

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "phx.gen.html" do
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.html Blog Post posts title:unique body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", RainyDayWeb do
              pipe_through [:browser]

              resources "/posts", PostController
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.html Blog Post posts title body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", RainyDayWeb do
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
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.json Blog Post posts title:unique body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", RainyDayWeb do
              pipe_through [:api]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.json Blog Post posts title body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", RainyDayWeb do
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
    test "has no compilation or formatter warnings" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella", "--live"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.live Blog Post posts title:unique body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", RainyDayWeb do
              pipe_through [:browser]

              live "/posts", PostLive.Index, :index
              live "/posts/new", PostLive.Form, :new
              live "/posts/:id", PostLive.Show, :show
              live "/posts/:id/edit", PostLive.Form, :edit
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite" do
      with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella", "--live"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.live Blog Post posts title body:string status:enum:unpublished:published:deleted), web_root_path)

        modify_file(Path.join(web_root_path, "lib/rainy_day_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/", RainyDayWeb do
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
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.auth Accounts User users --live), web_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    test "has no compilation or formatter warnings (--no-live)" do
      with_installer_tmp("new with defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), web_root_path)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite --live" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.auth Accounts User users --live), web_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    @tag database: :postgresql
    test "has a passing test suite --no-live" do
      with_installer_tmp("app_with_defaults", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "rainy_day", ["--umbrella"])
        web_root_path = Path.join(app_root_path, "apps/rainy_day_web")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), web_root_path)

        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end
