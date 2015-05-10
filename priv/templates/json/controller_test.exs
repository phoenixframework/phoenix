defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  alias <%= module %>
  @valid_attrs <%= inspect params %>
  @valid_params <%= singular %>: @valid_attrs
  @invalid_params <%= singular %>: %{}

  setup do
    conn = conn() |> put_req_header("accept", "application/json")
    {:ok, conn: conn}
  end

  test "GET /<%= plural %>", %{conn: conn} do
    conn = get conn, <%= singular %>_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "GET /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = get conn, <%= singular %>_path(conn, :show, <%= singular %>)
    assert json_response(conn, 200)["data"] == %{
      "id" => <%= singular %>.id
    }
  end

  test "POST /<%= plural %> with valid data", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @valid_params
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "POST /<%= plural %> with invalid data", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @invalid_params
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "PUT /<%= plural %>/:id with valid data", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @valid_params
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "PUT /<%= plural %>/:id with invalid data", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @invalid_params
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "DELETE /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = delete conn, <%= singular %>_path(conn, :delete, <%= singular %>)
    assert json_response(conn, 200)["data"]["id"]
    refute Repo.get(<%= alias %>, <%= singular %>.id)
  end
end
