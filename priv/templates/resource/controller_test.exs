defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  @valid_params [<%= singular %>: <%= sample_params %>]

  test "GET /<%= plural %>" do
    conn = get conn(), <%= singular %>_path(conn, :index)
    assert conn.resp_body =~ "Listing <%= plural %>"
  end

  test "GET /<%= plural %>/new" do
    conn = get conn(), <%= singular %>_path(conn, :new)
    assert conn.resp_body =~ "New <%= singular %>"
  end

  test "POST /<%= plural %>" do
    conn = post conn(), <%= singular %>_path(conn, :create), @valid_params
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
  end

  test "GET /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = get conn(), <%= singular %>_path(conn, :show, <%= singular %>.id)
    assert conn.resp_body =~ "Show <%= singular %>"
  end

  test "PUT /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = put conn(), <%= singular %>_path(conn, :update, <%= singular %>.id), @valid_params
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
  end

  test "DELETE /<%= plural %>/:id" do
    <%= singular %> = Repo.insert %<%= module %>{}
    conn = delete conn(), <%= singular %>_path(conn, :delete, <%= singular %>.id)
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
  end
end
