defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @create_attrs %{
<%= schema.params.create |> Enum.map(fn {key, val} -> "    #{key}: #{inspect(val)}" end) |> Enum.join(",\n") %>
  }
  @update_attrs %{
<%= schema.params.update |> Enum.map(fn {key, val} -> "    #{key}: #{inspect(val)}" end) |> Enum.join(",\n") %>
  }
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@create_attrs)
    <%= schema.singular %>
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all <%= schema.plural %>", %{conn: conn} do
      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create <%= schema.singular %>" do
    test "renders <%= schema.singular %> when data is valid", %{conn: conn} do
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, id))

      assert %{
               "id" => id<%= for {key, val} <- schema.params.create do %>,
               "<%= key %>" => <%= Phoenix.json_library().encode!(val) %><% end %>
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.<%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "renders <%= schema.singular %> when data is valid", %{conn: conn, <%= schema.singular %>: %<%= inspect schema.alias %>{id: id} = <%= schema.singular %>} do
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, id))

      assert %{
               "id" => id<%= for {key, val} <- schema.params.update do %>,
               "<%= key %>" => <%= Phoenix.json_library().encode!(val) %><% end %>
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = put(conn, Routes.<%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "deletes chosen <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = delete(conn, Routes.<%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.<%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>))
      end
    end
  end

  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    {:ok, <%= schema.singular %>: <%= schema.singular %>}
  end
end
