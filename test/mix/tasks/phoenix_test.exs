defmodule Mix.Tasks.PhoenixTest do
  use ExUnit.Case, async: true

  test "prints version" do
    Mix.Tasks.Phoenix.run []
    assert_received {:mix_shell, :info, ["Phoenix v" <> _]}
  end

  test "provide a list of available phoenix mix tasks" do
    Mix.Tasks.Phoenix.run []

    assert_received {:mix_shell, :info, ["mix phoenix.digest " <> _]}
    assert_received {:mix_shell, :info, ["mix phoenix.gen.secret" <> _]}
    assert_received {:mix_shell, :info, ["mix phoenix.routes" <> _]}
    assert_received {:mix_shell, :info, ["mix phoenix.server" <> _]}
  end

end
