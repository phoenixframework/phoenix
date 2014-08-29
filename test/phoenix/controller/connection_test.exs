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

  test "assign_error/3 and error/1 assign and return error" do
    conn = Connection.assign_error(%Conn{}, :throw, "boom")
    assert Connection.error(conn) == {:throw, "boom"}
  end

  test "named_params/1 returns the private named params" do
    conn = Conn.assign_private(%Conn{}, :phoenix_named_params, [key: "val"])
    assert Connection.named_params(conn) == [key: "val"]
  end
end
