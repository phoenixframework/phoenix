defmodule Phoenix.Plugs.AcceptsTest do
  use ExUnit.Case, async: true
  use ConnHelper
  alias Phoenix.Plugs

  @ct Plugs.ContentTypeFetcher.init([])
  @html Plugs.Accepts.init(["html"])
  @json Plugs.Accepts.init(["json"])

  defp stack(conn, opts) do
    conn
    |> fetch_params()
    |> Plugs.ContentTypeFetcher.call(@ct)
    |> Plugs.Accepts.call(opts)
  end

  test "returns the connection when Accept mime-extension is accepted" do
    conn = conn(:get, "/", [], [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}])
           |> stack(@html)
    refute conn.halted
  end

  test "halts the connection with 400 bad request if mime-extension not accepted" do
    conn = conn(:get, "/", [], [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}])
           |> stack(@json)
    assert conn.halted
    assert conn.status == 400
  end
end
