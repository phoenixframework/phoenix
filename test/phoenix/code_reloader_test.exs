defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.CodeReloader

  defmodule Endpoint do
    def config(:reloadable_paths) do
      ["web"]
    end
  end

  test "touch/0 touches and returns touched files" do
    assert CodeReloader.touch == []
  end

  test "reload!/1 sends recompilation through GenServer" do
    assert CodeReloader.reload!([]) == :noop
  end

  test "reloads on every request" do
    opts = CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> CodeReloader.call(opts)
    assert conn.state == :unset
  end

  def reload!(_) do
    {:error, "oops"}
  end

  test "render compilation error on failure" do
    opts = CodeReloader.init(reloader: &__MODULE__.reload!/1)
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> CodeReloader.call(opts)
    assert conn.state  == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops"
    assert conn.resp_body =~ "CompilationError at GET /"
  end

  test "reloadable_paths/1 prepends '--elixirc-paths' to reloadable_paths" do
    conn = conn(:get, "/") |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
    assert CodeReloader.reloadable_paths(conn) == ["--elixirc-paths", "web"]
  end
end
