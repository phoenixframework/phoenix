defmodule Mix.Tasks.Phx.Test do
  use ExUnit.Case

  test "provide a list of available phx mix tasks" do
    Mix.Tasks.Phx.run []
    assert_received {:mix_shell, :info, ["mix phx.digest" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.digest.clean" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.channel" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.cert" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.context" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.embedded" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.html" <> _]}
    assert_received {:mix_shell, :info, ["mix phx.gen.json" <> _]}
  end

  test "expects no arguments" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phx.run ["invalid"]
    end
  end
end
