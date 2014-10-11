defmodule Phoenix.Router.ConnectionTest do
  use ExUnit.Case, async: true
  use ConnHelper
  alias Plug.Conn
  alias Phoenix.Controller.Connection
  alias Phoenix.Controller.Errors
  alias Phoenix.Plugs

  test "action_name returns the private phoenix_action" do
    conn = Conn.put_private(%Conn{}, :phoenix_action, "show")
    assert Connection.action_name(conn) == "show"
  end

  test "controller_module returns the private phoenix_controller" do
    conn = Conn.put_private(%Conn{}, :phoenix_controller, "show")
    assert Connection.controller_module(conn) == "show"
  end

  test "response_content_type! raises UnfetchedContentType error if unfetched" do
    assert_raise Errors.UnfetchedContentType, fn ->
      Connection.response_content_type!(%Conn{})
    end
  end

  test "response_content_type returns :error if unfetched" do
    assert {:error, _msg} = Connection.response_content_type(%Conn{})
  end

  test "response_content_type! returns content type when fetched" do
    conn = Phoenix.Plugs.ContentTypeFetcher.fetch(%Conn{params: %{}})
    assert Connection.response_content_type!(conn) == "text/html"
  end

  test "response_content_type returns content type when fetched" do
    conn = Phoenix.Plugs.ContentTypeFetcher.fetch(%Conn{params: %{}})
    assert Connection.response_content_type(conn) == {:ok, "text/html"}
  end

  test "response_content_type falls back to text/html when mime is invalid" do
    conn = Plugs.ContentTypeFetcher.fetch(
     %Conn{params: %{}, req_headers: [{"accept", "somethingcrazy/abc"}]}
    )
    assert Connection.response_content_type!(conn) == "text/html"
  end

  test "put_layout/2 assigns the private put_layout" do
    conn = Connection.put_layout(%Conn{}, "print")
    assert Connection.layout(conn) == "print"
  end

  test "layout/1 retrieves the put_layout, defaulting to application" do
    assert Connection.layout(%Conn{}) == "application"
  end

  test "assign_error/3 and error/1 assign and return error" do
    conn = Connection.assign_error(%Conn{}, :throw, "boom")
    assert Connection.error(conn) == {:throw, "boom"}
  end
end
