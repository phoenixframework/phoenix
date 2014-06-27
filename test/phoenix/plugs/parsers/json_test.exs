defmodule Phoenix.Plugs.Parsers.JSONTest do
  use ExUnit.Case, async: true
  use Plug.Test

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Phoenix.Plugs.Parsers.JSON])
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end

  test "parses the request body" do
    headers = [{"content-type", "application/json"}]
    body = Jazz.encode!(%{id: 1})
    conn = parse(conn(:post, "/", body, headers: headers))
    assert conn.params["id"] == 1
  end

  test "raises ParseError with malformed JSON" do
    exception = assert_raise Phoenix.Plugs.Parsers.JSON.ParseError, fn ->
      headers = [{"content-type", "application/json"}]
      parse(conn(:post, "/", "invalid json", headers: headers))
    end
    assert Plug.Exception.status(exception) == 400
  end
end
