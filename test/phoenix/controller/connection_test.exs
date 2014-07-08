defmodule Phoenix.Router.ConnectionTest do
  use ExUnit.Case
  use PlugHelper
  alias Plug.Conn
  alias Phoenix.Controller.Connection
  alias Phoenix.Controller.Errors

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
end
