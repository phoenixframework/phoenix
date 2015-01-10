defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Endpoint do
    def config(:reloadable_paths) do
      ["web"]
    end
  end

  test "touch/0 touches and returns touched files" do
    assert Phoenix.CodeReloader.touch == []
  end

  test "reload!/1 sends recompilation through GenServer" do
    assert Phoenix.CodeReloader.reload!([]) == :noop
  end

  test "reloads on every request" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state == :unset
  end

  def reload!(_) do
    {:error, "oops"}
  end

  test "render compilation error on failure" do
    opts = Phoenix.CodeReloader.init(reloader: &__MODULE__.reload!/1)
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state  == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops"
    assert conn.resp_body =~ "CompilationError at GET /"
  end
end
