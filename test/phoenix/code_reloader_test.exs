defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  test "touch/0 touches and returns touched files" do
    assert Phoenix.CodeReloader.touch == []
  end

  test "reload!/0 sends recompilation through GenServer" do
    assert Phoenix.CodeReloader.reload! == :noop
  end

  def reload! do
    Process.get(:code_reloader)
  end

  @opts Phoenix.CodeReloader.init(reloader: &__MODULE__.reload!/0)

  test "reloads on every request" do
    Process.put(:code_reloader, :ok)
    conn = Phoenix.CodeReloader.call(conn(:get, "/"), @opts)
    assert conn.state == :unset
  end

  test "render compilation error on failure" do
    Process.put(:code_reloader, {:error, "oops"})
    conn = Phoenix.CodeReloader.call(conn(:get, "/"), @opts)
    assert conn.state  == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops"
    assert conn.resp_body =~ "CompilationError at GET /"
  end
end
