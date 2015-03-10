defmodule Phoenix.Endpoint.WatcherTest do
  use ExUnit.Case, async: true

  alias Phoenix.Endpoint.Watcher
  import ExUnit.CaptureIO

  # Used by watcher
  def config(:root), do: File.cwd!

  test "starts watching and writes to stdio" do
    assert capture_io(fn ->
      {:ok, pid} = Watcher.start_link(__MODULE__, "echo", ["hello"])
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end) == "hello\n"
  end
end
