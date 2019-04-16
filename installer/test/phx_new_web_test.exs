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
    assert capture_io(fn -> Mix.Tasks.Phx.New.Web.run([]) end) =~
           "Creates a new Phoenix web project within an umbrella project."
  end

  test "new with barebones umbrella" do
    in_tmp_umbrella_project "new with barebones umbrella", fn ->
      files = ~w[../config/dev.exs ../config/test.exs ../config/prod.exs ../config/prod.secret.exs]
      Enum.each(files, &File.rm/1)

      assert_file "../config/config.exs", &refute(&1 =~ ~S[import_config "#{Mix.env()}.exs"])
      Mix.Tasks.Phx.New.Web.run([@app_name])
      assert_file "../config/config.exs", &assert(&1 =~ ~S[import_config "#{Mix.env()}.exs"])
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

      assert_file "../config/config.exs", fn file ->
        assert file =~ "generators: [context_app: false]"
      end

      assert_file "#{@app_name}/mix.exs", fn file ->
        assert file =~ "{:jason, \"~> 1.0\"}"
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
