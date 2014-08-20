defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case
  use PlugHelper
  alias Phoenix.CodeReloader

  test "mix_compile/1 logs warning when Mix.Task is not loaded" do
    {_, log} = capture_log fn ->
      CodeReloader.mix_compile({:error, :nofile})
    end

    assert String.contains?(to_string(log),
      "add :mix to your list of dependencies or disable code reloading")
  end

  test "mix_compile/1 recompiles code Mix.Task loaded" do
    {_, log} = capture_log fn ->
      assert CodeReloader.mix_compile({:module, Mix.Task})
    end

    assert to_string(log) == ""
  end

  test "reload! sends recompile through GenServer" do
    {:ok, pid} = assert CodeReloader.start_link
    assert CodeReloader.reload!
    Process.exit(pid, :kill)
  end
end
