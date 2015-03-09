defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Endpoint do
    def config(:reloadable_paths), do: ["web"]
    def config(:live_reload),      do: ["some/path"]
  end

  defmodule EndpointNoLiveReload do
    def config(:reloadable_paths), do: ["web"]
    def config(:live_reload),      do: []
  end


  test "task touches files" do
    assert Mix.Tasks.Compile.Phoenix.run([]) == :noop
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

  test "injects live_reload for html requests if configured" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> put_resp_content_type("text/html")
           |> Phoenix.CodeReloader.call(opts)
           |> send_resp(200, "")
    assert to_string(conn.resp_body) =~ ~r/require\("phoenix"\)/
  end

  test "skips live_reload if not configured" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, EndpointNoLiveReload)
           |> put_resp_content_type("text/html")
           |> Phoenix.CodeReloader.call(opts)
           |> send_resp(200, "")
    refute to_string(conn.resp_body) =~ ~r/require\("phoenix"\)/
  end

  test "skips live_reload if not html request" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> put_resp_content_type("application/json")
           |> Phoenix.CodeReloader.call(opts)
           |> send_resp(200, "")
    refute to_string(conn.resp_body) =~ ~r/require\("phoenix"\)/
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
