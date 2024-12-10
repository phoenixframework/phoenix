defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  import <%= inspect(context.module) %>Fixtures

  alias <%= inspect schema.module %>

  @invalid_attrs %{<%= Mix.Phoenix.TestData.controller_invalid_attrs(schema) %>
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all <%= schema.plural %>", %{conn: conn} do
      conn = get(conn, ~p"<%= schema.api_route_prefix %>")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create <%= schema.singular %>" do
    test "renders <%= schema.singular %> when data is valid", %{conn: conn} do
<%= Mix.Phoenix.TestData.action_attrs_with_references(schema, :create) %>

      conn = post(conn, ~p"<%= schema.api_route_prefix %>", <%= schema.singular %>: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"<%= schema.api_route_prefix %>/#{id}")

      assert %{
<%= Mix.Phoenix.TestData.json_values_assertions(schema, :create) %>
             } = json_response(conn, 200)["data"]<%= Mix.Phoenix.TestData.json_references_values_assertions(schema) %>
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"<%= schema.api_route_prefix %>", <%= schema.singular %>: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "renders <%= schema.singular %> when data is valid", %{conn: conn, <%= schema.singular %>: %<%= inspect schema.alias %>{id: id} = <%= schema.singular %>} do
<%= Mix.Phoenix.TestData.action_attrs_with_references(schema, :update) %>

      conn = put(conn, ~p"<%= schema.api_route_prefix %>/#{<%= schema.singular %>}", <%= schema.singular %>: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"<%= schema.api_route_prefix %>/#{id}")

      assert %{
<%= Mix.Phoenix.TestData.json_values_assertions(schema, :update) %>
             } = json_response(conn, 200)["data"]<%= Mix.Phoenix.TestData.json_references_values_assertions(schema) %>
    end

    test "renders errors when data is invalid", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = put(conn, ~p"<%= schema.api_route_prefix %>/#{<%= schema.singular %>}", <%= schema.singular %>: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "deletes chosen <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      conn = delete(conn, ~p"<%= schema.api_route_prefix %>/#{<%= schema.singular %>}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"<%= schema.api_route_prefix %>/#{<%= schema.singular %>}")
      end
    end
  end

  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = <%= schema.singular %>_fixture()
    %{<%= schema.singular %>: <%= schema.singular %>}
  end
end
