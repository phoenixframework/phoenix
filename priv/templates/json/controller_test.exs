defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  alias <%= module %>
  @valid_params <%= singular %>: <%= inspect params %>

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

  test "POST /<%= plural %>", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @valid_params
    assert json_response(conn, 200)["data"]["id"]
  end

  test "PUT /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @valid_params
    assert json_response(conn, 200)["data"]["id"]
  end

  test "DELETE /<%= plural %>/:id", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = delete conn, <%= singular %>_path(conn, :delete, <%= singular %>)
    assert json_response(conn, 200)["data"]["id"]
    refute Repo.get(<%= alias %>, <%= singular %>.id)
  end
end
