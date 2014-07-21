defmodule Phoenix.Router.ConnectionTest do
  use ExUnit.Case
  use PlugHelper
  alias Plug.Conn
  alias Phoenix.Controller.Connection
  alias Phoenix.Controller.Errors
  alias Phoenix.Plugs

  test "action_name returns the private phoenix_action" do
    conn = Conn.assign_private(%Conn{}, :phoenix_action, "show")
    assert Connection.action_name(conn) == "show"
  end

  test "controller_module returns the private phoenix_controller" do
    conn = Conn.assign_private(%Conn{}, :phoenix_controller, "show")
    assert Connection.controller_module(conn) == "show"
  end

  test "halt! throws exception" do
    conn = %Conn{state: :unsent}
    assert catch_throw(Connection.halt!(conn)) == {:halt, conn}

    conn = %Conn{state: :sent}
    assert catch_throw(Connection.halt!(conn)) == {:halt, conn}
  end

  test "response_content_type raises UnfetchedContentType error if unfetched" do
    assert_raise Errors.UnfetchedContentType, fn ->
      Connection.response_content_type(%Conn{})
    end
  end

  test "response_content_type returns content type when fetched" do
    conn = Phoenix.Plugs.ContentTypeFetcher.fetch(%Conn{params: %{}})
    assert Connection.response_content_type(conn) == "text/html"
  end

  test "response_content_type falls back to text/html when mime is invalid" do
    conn = Plugs.ContentTypeFetcher.fetch(
     %Conn{params: %{}, req_headers: [{"accept", "somethingcrazy/abc"}]}
    )
    assert Connection.response_content_type(conn) == "text/html"
  end

  test "assign_layout/2 assigns the private assign_layout" do
    conn = Connection.assign_layout(%Conn{}, "print")
    assert Connection.layout(conn) == "print"
  end

  test "layout/1 retrieves the assign_layout, defaulting to application" do
    assert Connection.layout(%Conn{}) == "application"
  end

  test "assign_status/1 returns the conn.satus" do
    assert Connection.assign_status(%Conn{}, 404).status == 404
  end

  test "redirecting?/1 returns true when conn within redirect http status range" do
    for status <- 300..308 do
      assert Connection.redirecting?(struct(Conn, status: status))
    end
  end

  test "redirecting?/1 returns false when conn outside redirect http status range" do
    refute Connection.redirecting?(struct(Conn, status: 299))
    refute Connection.redirecting?(struct(Conn, status: 309))
    refute Connection.redirecting?(struct(Conn, status: 200))
    refute Connection.redirecting?(struct(Conn, status: 404))
  end
end
