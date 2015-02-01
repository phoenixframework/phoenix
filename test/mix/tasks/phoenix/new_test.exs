Code.require_file "../../mix_helper.exs", __DIR__

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
    on_exit fn -> delete_tmp_paths end

    :ok
  end

  test "new without a specified path" do
    in_tmp "new_without_a_specified_path", fn ->
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Phoenix.New.run([])
      end
    end
  end

  test "new with path" do
    in_tmp "new_with_path", fn ->
      Mix.Tasks.Phoenix.New.run([@app_name])

      project_path = Path.join(File.cwd!, @app_name)

      setup_project(project_path)

      creates_files_and_directories(project_path)
      compiles_and_recompiles_project(project_path)
    end
  end

  test "new with path and app name" do
    in_tmp "new_with_path_and_app_name", fn ->
      project_path = Path.join(File.cwd!, "custom_path")

      Mix.Tasks.Phoenix.New.run([project_path, "--app", @app_name])

      setup_project(project_path)

      creates_files_and_directories(project_path)
      compiles_and_recompiles_project(project_path)
    end
  end

  defp setup_project(project_path) do
    File.mkdir_p!(project_path)

    # Copy artifacts from Phoenix so we can compile and run tests
    File.cp_r "_build",   Path.join(project_path, "_build")
    File.cp_r "deps",     Path.join(project_path, "deps")
    File.cp_r "mix.lock", Path.join(project_path, "mix.lock")
  end
  
  defp creates_files_and_directories(project_path) do
    File.cd! project_path, fn ->
      assert_file ".gitignore"
      assert_file "README.md"
      assert_file "lib/photo_blog.ex", ~r/defmodule PhotoBlog do/
      assert_file "lib/photo_blog/endpoint.ex", ~r/defmodule PhotoBlog.Endpoint do/

      assert_file "priv/static/css/phoenix.css"
      assert_file "priv/static/images/phoenix.png"
      assert_file "priv/static/js/phoenix.js"

      assert_file "test/photo_blog_test.exs"
      assert_file "test/test_helper.exs"

      assert File.exists?("web/channels")
      refute File.exists?("web/channels/.keep")

      assert_file "web/controllers/page_controller.ex",
                  ~r/defmodule PhotoBlog.PageController/

      assert File.exists?("web/models")
      refute File.exists?("web/models/.keep")

      assert_file "web/views/page_view.ex",
                  ~r/defmodule PhotoBlog.PageView/

      assert_file "web/router.ex", ~r/defmodule PhotoBlog.Router/
      assert_file "web/view.ex", ~r/defmodule PhotoBlog.View/
    end
  end

  defp compiles_and_recompiles_project(project_path) do
    Logger.disable(self())
    Application.put_env(:phoenix, :code_reloader, true)

    Application.put_env(:photo_blog, PhotoBlog.Endpoint,
      secret_key_base: String.duplicate("abcdefgh", 8))

    in_project :photo_blog, project_path, fn _ ->
      Mix.Task.clear
      Mix.Task.run "compile", ["--no-deps-check"]
      assert_received {:mix_shell, :info, ["Compiled lib/photo_blog.ex"]}
      assert_received {:mix_shell, :info, ["Compiled web/router.ex"]}
      refute_received {:mix_shell, :info, ["Compiled lib/phoenix.ex"]}
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

      {:ok, _} = Application.ensure_all_started(:photo_blog)
      PhotoBlog.Endpoint.call(conn(:get, "/"), [])

      assert File.stat!("web/views/page_view.ex").mtime > @epoch

      # TODO: We need to uncomment this after we move to Elixir v1.0.3
      # as running tests would automatically shutdown the Logger.
      # assert capture_io(fn ->
      #   Mix.Task.run("test", ["--no-start", "--no-compile"])
      # end) =~ "1 tests, 0 failures"
    end
  after
    Application.put_env(:phoenix, :code_reloader, false)
  end

  defp delete_tmp_paths do
    tmp = tmp_path |> String.to_char_list
    for path <- :code.get_path,
      :string.str(path, tmp) != 0,
      do: :code.del_path(path)
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
end
