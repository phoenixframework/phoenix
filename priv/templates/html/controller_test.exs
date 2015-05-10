defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  alias <%= module %>
  @valid_attrs <%= inspect params %>
  @valid_params <%= singular %>: @valid_attrs
  @invalid_params <%= singular %>: %{}

  setup do
    conn = conn()
    {:ok, conn: conn}
  end

  test "GET /<%= plural %>", %{conn: conn} do
    conn = get conn, <%= singular %>_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing <%= plural %>"
  end

  test "GET /<%= plural %>/new", %{conn: conn} do
    conn = get conn, <%= singular %>_path(conn, :new)
    assert html_response(conn, 200) =~ "New <%= singular %>"
  end

  test "POST /<%= plural %> with valid data", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @valid_params
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "POST /<%= plural %> with invalid data", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @invalid_params
    assert html_response(conn, 200) =~ "New <%= singular %>"
  end

  test "GET /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = get conn, <%= singular %>_path(conn, :show, <%= singular %>)
    assert html_response(conn, 200) =~ "Show <%= singular %>"
  end

  test "GET /<%= plural %>/:id/edit", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = get conn, <%= singular %>_path(conn, :edit, <%= singular %>)
    assert html_response(conn, 200) =~ "Edit <%= singular %>"
  end

  test "PUT /<%= plural %>/:id with valid data", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @valid_params
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "PUT /<%= plural %>/:id with invalid data", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @invalid_params
    assert html_response(conn, 200) =~ "Edit <%= singular %>"
  end

  test "DELETE /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = delete conn, <%= singular %>_path(conn, :delete, <%= singular %>)
    assert redirected_to(conn) == <%= singular %>_path(conn, :index)
    refute Repo.get(<%= alias %>, <%= singular %>.id)
  end
end
