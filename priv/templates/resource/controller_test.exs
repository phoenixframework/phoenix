defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  test "GET /<%= plural %>" do
    conn = get conn(), "/<%= plural %>"
    assert conn.resp_body =~ "Listing <%= plural %>"
  end

  test "GET /<%= plural %>/new" do
    conn = get conn(), "/<%= plural %>/new"
    assert conn.resp_body =~ "New <%= singular %>"
  end

  test "POST /<%= plural %>" do
    conn = post conn(), "/<%= plural %>", %{"<%= plural %>" => []}
    assert conn.status == 302
  end

  test "GET /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = get conn(), "/<%= plural %>/#{<%= singular %>.id}"
    assert conn.resp_body =~ "Show <%= singular %>"
  end

  test "PUT /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = put conn(), "/<%= plural %>/#{<%= singular %>.id}", %{"<%= plural %>" => []}
    assert conn.status == 302
  end

  test "DELETE /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = delete conn(), "/<%= plural %>/#{<%= singular %>.id}"
    assert conn.status == 302
  end
end
