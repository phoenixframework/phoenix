Code.require_file "../../../installer/lib/mix/tasks/phoenix.new.ex", __DIR__
Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

# Here we test the installer is up to date.
defmodule Mix.Tasks.Phoenix.NewTest do
  use ExUnit.Case
  use RouterHelper

  import MixHelper
  import ExUnit.CaptureIO

  @moduletag :phoenix_new
  @epoch {{1970, 1, 1}, {0, 0, 0}}

  setup do
    # The shell asks to install npm and mix deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "bootstraps generated project" do
    Logger.disable(self())

    Application.put_env(:photo_blog, PhotoBlog.Endpoint,
      secret_key_base: String.duplicate("abcdefgh", 8),
      code_reloader: true)

    in_tmp "deprecated_bootstrap", fn ->
      Mix.Tasks.Phoenix.New.run(["photo_blog", "--no-brunch", "--no-ecto"])
    end

    # Copy artifacts from Phoenix so we can compile and run tests
    File.cp_r "_build",   "deprecated_bootstrap/photo_blog/_build"
    File.cp_r "deps",     "deprecated_bootstrap/photo_blog/deps"
    File.cp_r "mix.lock", "deprecated_bootstrap/photo_blog/mix.lock"

    in_project :photo_blog, Path.join(tmp_path(), "deprecated_bootstrap/photo_blog"), fn _ ->
      Mix.Task.clear
      Mix.Task.run "compile", ["--no-deps-check"]
      assert_received {:mix_shell, :info, ["Generated photo_blog app"]}
      refute_received {:mix_shell, :info, ["Generated phoenix app"]}
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

      # Ensure /priv static files are copied
      assert File.exists?("priv/static/js/phoenix.js")

      # We can run tests too, starting the app.
      assert capture_io(fn ->
        capture_io(:user, fn ->
          Mix.Task.run("test", ["--no-start", "--no-compile"])
        end)
      end) =~ ~r"4 tests, 0 failures"
    end
  after
    Code.delete_path Path.join(tmp_path(), "deprecated_bootstrap/photo_blog/_build/test/consolidated")
    Code.delete_path Path.join(tmp_path(), "deprecated_bootstrap/photo_blog/_build/test/lib/photo_blog/ebin")
  end
end
