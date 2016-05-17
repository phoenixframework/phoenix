defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:phoenix, __MODULE__.Endpoint,
    root: File.cwd!,
    code_reloader: true,
    live_reload: [url: "ws://localhost:4000", patterns: [~r/some\/path/]])

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

  test "reloads on every request" do
    children = Supervisor.which_children(Endpoint)
    assert {Phoenix.CodeReloader.Server, pid, _, _} =
           List.keyfind(children, Phoenix.CodeReloader.Server, 0)
    :erlang.trace(pid, true, [:receive])

    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state == :unset

    assert_receive {:trace, ^pid, :receive, {_, _, :reload!}}
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
end
