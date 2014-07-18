defmodule Phoenix.Plugs.ContentTypeFetcherTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Phoenix.Plugs.ContentTypeFetcher
  alias Phoenix.Controller.Connection

  test "accept_formats returns a list of mime types from Accept header" do
    conn = %Conn{req_headers: [{"accept", "text/html,application/xml;q=0.9,*/*;q=0.8"}]}
    assert ContentTypeFetcher.accept_formats(conn) == ["text/html", "application/xml", "*/*"]

    conn = %Conn{req_headers: [{"accept", "text/html;q=0.9"}]}
    assert ContentTypeFetcher.accept_formats(conn) == ["text/html"]

    conn = %Conn{req_headers: [{"accept", "text/html"}]}
    assert ContentTypeFetcher.accept_formats(conn) == ["text/html"]

    conn = %Conn{}
    assert ContentTypeFetcher.accept_formats(conn) == []
  end

  test "response_content_type defaults to text/html" do
    conn = Plug.Conn.fetch_params(%Conn{})
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "text/html"
  end

  test "response_content_type returns text/html when */*" do
    conn = %Conn{params: %{}, req_headers: [{"accept", "*/*"}]}
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "text/html"
  end

  test "response_content_type prefers format param when available" do
    conn = %Conn{params: %{"format" => "json"}, req_headers: [{"accept", "text/html"}]}
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "application/json"
  end

  test "response_content_type uses accept header when format param missing" do
    conn = %Conn{params: %{}, req_headers: [{"accept", "application/xml"}]}
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "application/xml"
  end

  test "response_content_type falls back to text/html when format and Accepet missing" do
    conn = %Conn{params: %{}, req_headers: []}
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "text/html"
  end

  test "response_content_type falls back to text/html when mime is invalid" do
    conn = %Conn{params: %{}, req_headers: [{"accept", "somethingcrazy/abc"}]}
    |> ContentTypeFetcher.fetch
    assert Connection.response_content_type(conn) == "text/html"
  end


end
