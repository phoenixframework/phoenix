defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Endpoint do
    def config(:reloadable_compilers) do
      [:gettext, :phoenix, :elixir]
    end
  end

  def reload!(_) do
    {:error, "oops"}
  end

  test "compile.phoenix tasks touches files" do
    assert Mix.Tasks.Compile.Phoenix.run([]) == :noop
  end

  test "reloads on every request" do
    pid = Process.whereis(Phoenix.CodeReloader.Server)
    :erlang.trace(pid, true, [:receive])

    opts = Phoenix.CodeReloader.init([])
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state == :unset

    assert_receive {:trace, ^pid, :receive, {_, _, {:reload!, Endpoint}}}
  end

  test "renders compilation error on failure" do
    opts = Phoenix.CodeReloader.init(reloader: &__MODULE__.reload!/1)
    conn = conn(:get, "/")
           |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
           |> Phoenix.CodeReloader.call(opts)
    assert conn.state  == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops"
    assert conn.resp_body =~ "CompileError"
    assert conn.resp_body =~ "Compilation error"
  end
end
