defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:phoenix, __MODULE__.Endpoint,
    root: File.cwd!,
    code_reloader: true,
    reloadable_paths: ["web"],
    live_reload: ["some/path"])

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

  def reload!(_) do
    {:error, "oops"}
  end

  test "compile.phoenix tasks touches files" do
    assert Mix.Tasks.Compile.Phoenix.run([]) == :noop
  end

  test "starts the code reloader server" do
    children = Supervisor.which_children(Endpoint)
    assert {Phoenix.CodeReloader.Server, _, _, _} =
           List.keyfind(children, Phoenix.CodeReloader.Server, 0)
  end

  test "reloads on every request" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state == :unset
  end

  test "renders compilation error on failure" do
    opts = Phoenix.CodeReloader.init(reloader: &__MODULE__.reload!/1)
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state  == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops"
    assert conn.resp_body =~ "CompilationError at GET /"
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

  test "skips live_reload if not html request" do
    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> put_resp_content_type("application/json")
           |> Phoenix.CodeReloader.call(opts)
           |> send_resp(200, "")
    refute to_string(conn.resp_body) =~ ~r/require\("phoenix"\)/
  end
end
