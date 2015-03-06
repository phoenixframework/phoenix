Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.NewTest do
  # This test case needs to be sync because we rely on
  # changing the current working directory which is global.
  use ExUnit.Case
  use Plug.Test

  import MixHelper
  import ExUnit.CaptureIO

  @epoch {{1970, 1, 1}, {0, 0, 0}}
  @app_name "photo_blog"

  setup do
    # The shell asks to install npm and mix deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "bootstraps generated project" do
    Logger.disable(self())
    Application.put_env(:phoenix, :code_reloader, true)
    Application.put_env(:photo_blog, PhotoBlog.Endpoint,
      secret_key_base: String.duplicate("abcdefgh", 8))

    in_tmp "bootstrap", fn ->
      Mix.Tasks.Phoenix.New.run([@app_name])
    end

    # Copy artifacts from Phoenix so we can compile and run tests
    File.cp_r "_build",   "bootstrap/photo_blog/_build"
    File.cp_r "deps",     "bootstrap/photo_blog/deps"
    File.cp_r "mix.lock", "bootstrap/photo_blog/mix.lock"

    in_project :photo_blog, Path.join(tmp_path, "bootstrap/photo_blog"), fn _ ->
      Mix.Task.clear
      Mix.Task.run "compile", ["--no-deps-check"]
      assert_received {:mix_shell, :info, ["Compiled lib/photo_blog.ex"]}
      assert_received {:mix_shell, :info, ["Compiled web/router.ex"]}
      refute_received {:mix_shell, :info, ["Compiled lib/phoenix.ex"]}
      Mix.shell.flush

      # Adding a new template touches file (through mix)
      File.touch! "web/views/layout_view.ex", @epoch
      File.write! "web/templates/layout/another.html.eex", "oops"

      Mix.Task.clear
      Mix.Task.run "compile", ["--no-deps-check"]
      assert File.stat!("web/views/layout_view.ex").mtime > @epoch

      # Adding a new template triggers recompilation (through request)
      File.touch! "web/views/page_view.ex", @epoch
      File.write! "web/templates/page/another.html.eex", "oops"

      {:ok, _} = Application.ensure_all_started(:photo_blog)
      PhotoBlog.Endpoint.call(conn(:get, "/"), [])
      assert File.stat!("web/views/page_view.ex").mtime > @epoch

      # We can run tests too, starting the app.
      assert capture_io(fn ->
        Mix.Task.run("test", ["--no-start", "--no-compile"])
      end) =~ ~r"1 tests?, 0 failures"
    end
  after
    Application.put_env(:phoenix, :code_reloader, false)
  end

  test "new with path" do
    in_tmp "new with path", fn ->
      Mix.Tasks.Phoenix.New.run([@app_name])

      assert_file "photo_blog/.gitignore"
      assert_file "photo_blog/README.md"
      assert_file "photo_blog/mix.exs", fn(file) ->
        assert file =~ "app: :photo_blog"
        refute file =~ "deps_path: \"../../deps\""
        refute file =~ "lockfile: \"../../mix.lock\""
      end

      assert_file "photo_blog/lib/photo_blog.ex", ~r/defmodule PhotoBlog do/
      assert_file "photo_blog/lib/photo_blog/endpoint.ex", ~r/defmodule PhotoBlog.Endpoint do/

      refute File.exists? "photo_blog/priv/static/css/app.css"
      refute File.exists? "photo_blog/priv/static/images/phoenix.png"
      refute File.exists? "photo_blog/priv/static/js/phoenix.js"
      refute File.exists? "photo_blog/priv/static/js/app.js"

      assert_file "photo_blog/test/photo_blog_test.exs"
      assert_file "photo_blog/test/test_helper.exs"

      assert File.exists?("photo_blog/web/channels")
      refute File.exists?("photo_blog/web/channels/.keep")

      assert_file "photo_blog/web/controllers/page_controller.ex",
                  ~r/defmodule PhotoBlog.PageController/

      assert File.exists?("photo_blog/web/models")
      refute File.exists?("photo_blog/web/models/.keep")

      assert_file "photo_blog/web/views/page_view.ex",
                  ~r/defmodule PhotoBlog.PageView/

      assert_file "photo_blog/web/router.ex", ~r/defmodule PhotoBlog.Router/
      assert_file "photo_blog/web/web.ex", ~r/defmodule PhotoBlog.Web/

      # Brunch (default)
      assert_file "photo_blog/.gitignore", ~r"/node_modules"
      assert_file "photo_blog/web/static/vendor/phoenix.js"
      assert_file "photo_blog/web/static/js/app.js"
      assert_file "photo_blog/web/static/css/app.scss"
      assert_file "photo_blog/web/static/assets/images/phoenix.png"
      assert_file "photo_blog/config/dev.exs", ~r/watchers:/

      # Questions
      assert_received {:mix_shell, :yes?, ["\nInstall brunch.io dependencies?"]}
      assert_received {:mix_shell, :yes?, ["\nInstall mix dependencies?"]}
    end
  end

  test "new without brunch" do
    in_tmp "new without brunch", fn ->
      Mix.Tasks.Phoenix.New.run(["app_no_brunch", "--app", @app_name, "--no-brunch"])

      refute File.read!("app_no_brunch/config/dev.exs") =~ ~r/watchers:/
      refute File.read!("app_no_brunch/.gitignore") |> String.contains?("/node_modules")

      assert_file "app_no_brunch/priv/static/css/app.css"
      assert_file "app_no_brunch/priv/static/images/phoenix.png"
      assert_file "app_no_brunch/priv/static/js/phoenix.js"
      assert_file "app_no_brunch/priv/static/js/app.js"
    end
  end

  test "new with path and app name" do
    in_tmp "new with path and app name", fn ->
      project_path = Path.join(File.cwd!, "custom_path")
      Mix.Tasks.Phoenix.New.run([project_path, "--app", @app_name])

      assert_file "custom_path/.gitignore"
      assert_file "custom_path/mix.exs", ~r/app: :photo_blog/
      assert_file "custom_path/lib/photo_blog/endpoint.ex", ~r/app: :photo_blog/
    end
  end

  test "new inside umbrella" do
    in_tmp "new inside umbrella", fn ->
      File.write! "mix.exs", umbrella_mixfile_contents
      File.mkdir! "apps"
      File.cd! "apps", fn ->
        Mix.Tasks.Phoenix.New.run([@app_name])

        assert_file "photo_blog/mix.exs", fn(file) ->
          assert file =~ "deps_path: \"../../deps\""
          assert file =~ "lockfile: \"../../mix.lock\""
        end
      end
    end
  end

  test "new with invalid args" do
    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phoenix.New.run ["007invalid"]
    end

    assert_raise Mix.Error, ~r"Application name must start with a letter and ", fn ->
      Mix.Tasks.Phoenix.New.run ["valid", "--app", "007invalid"]
    end

    assert_raise Mix.Error, ~r"Module name must be a valid Elixir alias", fn ->
      Mix.Tasks.Phoenix.New.run ["valid", "--module", "not.valid"]
    end

    assert_raise Mix.Error, "Expected PATH to be given, please use `mix phoenix.new PATH`", fn ->
      Mix.Tasks.Phoenix.New.run []
    end
  end

  defp in_tmp(which, function) do
    path = Path.join(tmp_path, which)
    File.rm_rf! path
    File.mkdir_p! path
    File.cd! path, function
  end

  defp in_project(app, path, fun) do
    %{name: name, file: file} = Mix.Project.pop

    try do
      capture_io :stderr, fn ->
        Mix.Project.in_project app, path, [], fun
      end
    after
      Mix.Project.push name, file
    end
  end

  defp umbrella_mixfile_contents do
    """
defmodule Umbrella.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     deps: deps]
  end

  defp deps do
    []
  end
end
    """
  end
end
