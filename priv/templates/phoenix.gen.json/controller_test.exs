defmodule <%= module %>ControllerTest do
  use <%= base %>.ConnCase

  alias <%= module %>
  @valid_attrs <%= inspect params %>
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= singular %>_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    <%= singular %> = Repo.insert! %<%= alias %>{}
    conn = get conn, <%= singular %>_path(conn, :show, <%= singular %>)
    assert json_response(conn, 200)["data"] == %{"id" => <%= singular %>.id<%= for {k, _} <- attrs do %>,
      "<%= k %>" => <%= singular %>.<%= k %><% end %>}
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, <%= singular %>_path(conn, :show, <%= inspect sample_id %>)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), <%= singular %>: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, <%= singular %>_path(conn, :create), <%= singular %>: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    <%= singular %> = Repo.insert! %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), <%= singular %>: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(<%= alias %>, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    <%= singular %> = Repo.insert! %<%= alias %>{}
    conn = put conn, <%= singular %>_path(conn, :update, <%= singular %>), <%= singular %>: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    <%= singular %> = Repo.insert! %<%= alias %>{}
    conn = delete conn, <%= singular %>_path(conn, :delete, <%= singular %>)
    assert response(conn, 204)
    refute Repo.get(<%= alias %>, <%= singular %>.id)
  end
end
