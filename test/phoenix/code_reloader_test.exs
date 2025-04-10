defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Endpoint do
    def config(:reloadable_compilers), do: [:unknown_compiler, :elixir]
    def config(:reloadable_apps), do: nil
  end

  def reload(_, _) do
    {:error, "oops \e[31merror"}
  end

  @tag :capture_log
  test "syncs with code server" do
    assert Phoenix.CodeReloader.sync() == :ok

    # Suspend so we can monitor the process until we get a reply.
    # There is an inherent race condition here in that the process
    # may die before we request but the code should work in both
    # cases, so we are fine.
    :sys.suspend(Phoenix.CodeReloader.Server)
    ref = Process.monitor(Phoenix.CodeReloader.Server)

    Task.start_link(fn ->
      Phoenix.CodeReloader.Server
      |> Process.whereis()
      |> Process.exit(:kill)
    end)

    assert Phoenix.CodeReloader.sync() == :ok
    assert_receive {:DOWN, ^ref, _, _, _}
    wait_until_is_up(Phoenix.CodeReloader.Server)
  end

  test "reloads on every request" do
    pid = Process.whereis(Phoenix.CodeReloader.Server)
    :erlang.trace(pid, true, [:receive])

    opts = Phoenix.CodeReloader.init([])

    conn =
      conn(:get, "/")
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Phoenix.CodeReloader.call(opts)

    assert conn.state == :unset

    assert_receive {:trace, ^pid, :receive, {_, _, {:reload!, Endpoint, _}}}
  end

  test "renders compilation error on failure" do
    opts = Phoenix.CodeReloader.init(reloader: &__MODULE__.reload/2)

    conn =
      conn(:get, "/")
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Phoenix.CodeReloader.call(opts)

    assert conn.state == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops error"
    assert conn.resp_body =~ "CompileError"
    assert conn.resp_body =~ "Compilation error"
  end

  defp wait_until_is_up(process) do
    if Process.whereis(process) do
      :ok
    else
      Process.sleep(10)
      wait_until_is_up(process)
    end
  end
end
