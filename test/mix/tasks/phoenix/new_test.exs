defmodule Mix.Tasks.Phoenix.NewTest do
  use ExUnit.Case

  @app_name "photo_blog"
  @destination_path "/tmp"

  setup_all do
    File.rm_rf(project_path)
    Mix.Tasks.Phoenix.New.run([@app_name, @destination_path])
    on_exit fn() -> File.rm_rf(project_path) end
    :ok
  end

  test "creates files and directories" do
    expected_files = [".gitignore",
      "README.md",
      "lib",
      "lib/photo_blog.ex",
      "web/controllers/page_controller.ex",
      "web/router.ex",
      "mix.exs",
      "test",
      "test/photo_blog_test.exs",
      "test/test_helper.exs"]

    for file <- expected_files do
      path = Path.join(project_path, file)

      assert File.exists?(path)
    end
  end

  test "files contain application name" do
    path = Path.join(project_path, "lib/photo_blog.ex")
    {:ok, content} = File.read(path)

    assert Regex.match?(~r/PhotoBlog/, content)
  end

  test "missing name and/or path arguments" do
    assert Mix.Tasks.Phoenix.New.run([])
    assert Mix.Tasks.Phoenix.New.run([@app_name])
  end

  def project_path do
    Path.join(@destination_path, @app_name)
  end
end
