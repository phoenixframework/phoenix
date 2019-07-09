Code.require_file "mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.New.EctoTest do
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  setup do
    # The shell asks to install deps.
    # We will politely say not.
    send self(), {:mix_shell_input, :yes?, false}
    :ok
  end

  @app_name "phx_ecto"

  test "new without args" do
    assert capture_io(fn -> Mix.Tasks.Phx.New.Ecto.run([]) end) =~
           "Creates a new Ecto project within an umbrella project."
  end

  test "new with barebones umbrella" do
    in_tmp_umbrella_project "new with barebones umbrella", fn ->
      files = ~w[../config/dev.exs ../config/test.exs ../config/prod.exs ../config/prod.secret.exs]
      Enum.each(files, &File.rm/1)

      assert_file "../config/config.exs", &refute(&1 =~ ~S[import_config "#{Mix.env()}.exs"])
      Mix.Tasks.Phx.New.Ecto.run([@app_name])
      assert_file "../config/config.exs", &assert(&1 =~ ~S[import_config "#{Mix.env()}.exs"])
    end
  end

  test "new outside umbrella", config do
    in_tmp config.test, fn ->
      assert_raise Mix.Error, ~r"The ecto task can only be run within an umbrella's apps directory", fn ->
        Mix.Tasks.Phx.New.Ecto.run ["007invalid"]
      end
    end
  end

  test "new with defaults", config do
    in_tmp_umbrella_project config.test, fn ->
      Mix.Tasks.Phx.New.Ecto.run([@app_name])

      # Install dependencies?
      assert_received {:mix_shell, :yes?, ["\nFetch and install dependencies?"]}

      # Instructions
      assert_received {:mix_shell, :info, ["\nWe are almost there" <> _ = msg]}
      assert msg =~ "$ cd phx_ecto"
      assert msg =~ "$ mix deps.get"

      assert_received {:mix_shell, :info, ["Then configure your database in config/dev.exs" <> _]}
    end
  end
end
