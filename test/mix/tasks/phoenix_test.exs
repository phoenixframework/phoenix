defmodule Mix.Tasks.PhoenixTest do
  use ExUnit.Case, async: true

  test "prints version" do
    Mix.Tasks.Phoenix.run []
    assert_received { :mix_shell, :info, ["Phoenix v" <> _]}
  end

  test "provide a list of available phoenix mix tasks" do
    Mix.Tasks.Phoenix.run []

    assert_received { :mix_shell, :info, ["mix phoenix.digest " <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.digest.clean " <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.channel" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.html" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.json" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.model" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.presence" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.gen.secret" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.routes" <> _]}
    assert_received { :mix_shell, :info, ["mix phoenix.server" <> _]}
  end

  test "expects no arguments" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.run ["invalid"]
    end
  end

end
