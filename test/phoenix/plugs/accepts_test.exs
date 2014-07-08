defmodule Phoenix.Plugs.AcceptsTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Phoenix.Plugs

  defmodule HtmlController do
    use Phoenix.Controller
    plug Plugs.Accepts, ["html"]
    def show(conn, _), do: conn
  end

  defmodule JsonController do
    use Phoenix.Controller
    plug Plugs.Accepts, ["json"]
    def show(conn, _), do: conn
  end


  test "returns the connection when Accept mime-extension is accepted" do
    conn = Plug.Test.conn(:get, "/")
    conn = put_in conn.req_headers, [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}]
    conn = Phoenix.Controller.perform_action(conn, HtmlController, :show, [])

    refute conn.status == 400
  end

  test "halts the connection with 400 bad request if mime-extension not accepted" do
    conn = Plug.Test.conn(:get, "/")
    conn = put_in conn.req_headers, [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}]

    {:halt, conn} = catch_throw(Phoenix.Controller.perform_action(conn, JsonController, :show, []))

    assert conn.status == 400
  end

end
