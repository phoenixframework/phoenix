defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @create_attrs <%= inspect schema.params.create %>
  @update_attrs <%= inspect schema.params.update %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@create_attrs)
    <%= schema.singular %>
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= schema.route_helper %>_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "creates <%= schema.singular %> and renders <%= schema.singular %> when data is valid", %{conn: conn} do
    conn = post conn, <%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get conn, <%= schema.route_helper %>_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id<%= for {key, val} <- schema.params.create do %>,
      "<%= key %>" => <%= inspect val %><% end %>}
  end

  test "does not create <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, <%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen <%= schema.singular %> and renders <%= schema.singular %> when data is valid", %{conn: conn} do
    %<%= inspect schema.alias %>{id: id} = <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = put conn, <%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, <%= schema.route_helper %>_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id<%= for {key, val} <- schema.params.update do %>,
      "<%= key %>" => <%= inspect val %><% end %>}
  end

  test "does not update chosen <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = put conn, <%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = delete conn, <%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, <%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>)
    end
  end
end
