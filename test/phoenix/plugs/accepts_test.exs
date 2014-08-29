defmodule Phoenix.Plugs.AcceptsTest do
  use ExUnit.Case, async: true
  use PlugHelper
  alias Phoenix.Plugs
  alias Phoenix.Controller.Action

  defmodule HtmlController do
    use Phoenix.Controller
    plug Plugs.Accepts, ["html"]
    def show(conn, _), do: text(conn, "ok")
  end

  defmodule JsonController do
    use Phoenix.Controller
    plug Plugs.Accepts, ["json"]
    def show(conn, _), do: text(conn, "ok")
  end


  test "returns the connection when Accept mime-extension is accepted" do
    conn = Plug.Test.conn(:get, "/")
    conn = put_in conn.req_headers, [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}]
    refute conn.halted
    {conn, _} = capture_log fn ->
      Action.perform(conn, HtmlController, :show, [])
    end
    refute conn.halted
    assert conn.status == 200
  end

  test "halts the connection with 400 bad request if mime-extension not accepted" do
    conn = Plug.Test.conn(:get, "/")
    conn = put_in conn.req_headers, [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}]

    refute conn.halted
    {conn, _} = capture_log fn ->
      Action.perform(conn, JsonController, :show, [])
    end
    assert conn.halted
    assert conn.status == 400
  end
end
