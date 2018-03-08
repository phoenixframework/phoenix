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

  test "new without args" do
    in_tmp_umbrella_project "new without args", fn ->
      assert capture_io(fn -> Mix.Tasks.Phx.New.Ecto.run([]) end) =~
             "Creates a new Ecto project within an umbrella project."
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
      Mix.Tasks.Phx.New.Ecto.run(["phx_ecto"])

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
