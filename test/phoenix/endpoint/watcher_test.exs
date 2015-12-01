defmodule Phoenix.Endpoint.WatcherTest do
  use ExUnit.Case, async: true

  alias Phoenix.Endpoint.Watcher
  import ExUnit.CaptureIO

  test "starts watching and writes to stdio" do
    assert capture_io(fn ->
      {:ok, pid} = Watcher.start_link(File.cwd!, "echo", ["hello"])
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end) == "hello\n"
  end
end
