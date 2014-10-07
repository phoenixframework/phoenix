Code.require_file "../../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.NewTest do
  use ExUnit.Case
  use Plug.Test

  import MixHelper
  import ExUnit.CaptureIO

  @app_name  "photo_blog"
  @tmp_path  tmp_path()
  @project_path Path.join(@tmp_path, @app_name)
  @epoch {{1970, 1, 1}, {0, 0, 0}}

  setup_all do
    # Clean up and create a new project
    File.rm_rf(@project_path)
    Mix.Tasks.Phoenix.New.run(["--dev", @app_name, @project_path])

    # Copy artifacts from Phoenix so we can compile and run tests
    File.cp_r "_build",   Path.join(@project_path, "_build")
    File.cp_r "deps",     Path.join(@project_path, "deps")
    File.cp_r "mix.lock", Path.join(@project_path, "mix.lock")

    :ok
  end

  test "creates files and directories" do
    File.cd! @project_path, fn ->
      assert_file ".gitignore"
      assert_file "README.md"
      assert_file "lib/photo_blog.ex", ~r/defmodule PhotoBlog do/

      assert_file "priv/static/css/phoenix.css"
      assert_file "priv/static/images/phoenix.png"
      assert_file "priv/static/js/phoenix.js"

      assert_file "test/photo_blog_test.exs"
      assert_file "test/test_helper.exs"

      assert_file "web/controllers/page_controller.ex", ~r/defmodule PhotoBlog.PageController/
      assert_file "web/router.ex", ~r/defmodule PhotoBlog.Router/
    end
  end

  test "compiles and recompiles project" do
    Logger.disable(self())
    Application.put_env(:phoenix, :code_reloader, true)

    in_project :photo_blog, @project_path, fn _ ->
      Mix.Task.run "compile", ["--no-deps-check"]
      assert_received {:mix_shell, :info, ["Compiled lib/photo_blog.ex"]}
      assert_received {:mix_shell, :info, ["Compiled web/router.ex"]}
      Mix.shell.flush
      Mix.Task.clear

      # Adding a new template touches file (through mix)
      File.touch! "web/views/layout_view.ex", @epoch
      File.write! "web/templates/layout/another.html.eex", "oops"
      Mix.Task.run "compile", ["--no-deps-check"]
      assert File.stat!("web/views/layout_view.ex").mtime > @epoch

      # Adding a new template triggers recompilation (through request)
      File.touch! "web/views/page_view.ex", @epoch
      File.write! "web/templates/page/another.html.eex", "oops"
      PhotoBlog.Router.call(conn(:get, "/"), [])
      assert File.stat!("web/views/page_view.ex").mtime > @epoch
    end
  after
    Application.put_env(:phoenix, :code_reloader, false)
  end

  test "missing name and/or path arguments" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.New.run([])
    end
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
end
