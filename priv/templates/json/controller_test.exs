defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  alias <%= module %>
  @valid_params <%= singular %>: <%= inspect params %>
  @invalid_params <%= singular %>: %{}

  setup do
    conn = conn() |> put_req_header("accept", "application/json")
    {:ok, conn: conn}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= singular %>_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = get conn, <%= singular %>_path(conn, :show, <%= singular %>)
    assert json_response(conn, 200)["data"] == %{
      "id" => <%= singular %>.id
    }
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @valid_params
    assert json_response(conn, 200)["data"]["id"]
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), @invalid_params
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @valid_params
    assert json_response(conn, 200)["data"]["id"]
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), @invalid_params
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    <%= singular %> = Repo.insert %<%= alias %>{}
    conn = delete conn, <%= singular %>_path(conn, :delete, <%= singular %>)
    assert json_response(conn, 200)["data"]["id"]
    refute Repo.get(<%= alias %>, <%= singular %>.id)
  end
end
