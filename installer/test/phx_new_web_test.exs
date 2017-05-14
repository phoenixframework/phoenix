Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.New.WebTest do
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  @app_name "phx_web"

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  test "new without args" do
    in_tmp_umbrella_project "new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Phx.New.Web.run([]) end) =~
             "Creates a new Phoenix web project within an umbrella application."
    end
  end

  test "new outside umbrella", config do
    in_tmp config.test, fn ->
      assert_raise Mix.Error, ~r"The web task can only be run within an umbrella's apps directory", fn ->
        Mix.Tasks.Phx.New.Web.run ["007invalid"]
      end
    end
  end

  test "new with defaults" do
    in_tmp_umbrella_project "new with defaults", fn ->
      Mix.Tasks.Phx.New.Web.run([@app_name])

      assert_file "#{@app_name}/config/config.exs", fn file ->
        assert file =~ "config :#{@app_name}, :generators,"
        assert file =~ "context_app: false"
      end

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_web"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Start your Phoenix app" <> _]}
    end
  end
end
