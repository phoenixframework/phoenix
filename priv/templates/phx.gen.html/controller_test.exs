defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  alias <%= inspect context.module %>

  @create_attrs <%= inspect schema.params.create %>
  @update_attrs <%= inspect schema.params.update %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@create_attrs)
    <%= schema.singular %>
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= schema.route_helper %>_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing <%= schema.human_plural %>"
  end

  test "renders form for new <%= schema.plural %>", %{conn: conn} do
    conn = get conn, <%= schema.route_helper %>_path(conn, :new)
    assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
  end

  test "creates <%= schema.singular %> and redirects to show when data is valid", %{conn: conn} do
    conn = post conn, <%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @create_attrs

    assert %{id: id} = redirected_params(conn)
    assert redirected_to(conn) == <%= schema.route_helper %>_path(conn, :show, id)

    conn = get conn, <%= schema.route_helper %>_path(conn, :show, id)
    assert html_response(conn, 200) =~ "Show <%= schema.human_singular %>"
  end

  test "does not create <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, <%= schema.route_helper %>_path(conn, :create), <%= schema.singular %>: @invalid_attrs
    assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
  end

  test "renders form for editing chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = get conn, <%= schema.route_helper %>_path(conn, :edit, <%= schema.singular %>)
    assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"
  end

  test "updates chosen <%= schema.singular %> and redirects when data is valid", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = put conn, <%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @update_attrs
    assert redirected_to(conn) == <%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>)

    conn = get conn, <%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>)<%= if schema.string_attr do %>
    assert html_response(conn, 200) =~ <%= inspect Mix.Phoenix.Schema.default_param(schema, :update) %><% else %>
    assert html_response(conn, 200)<% end %>
  end

  test "does not update chosen <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = put conn, <%= schema.route_helper %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"
  end

  test "deletes chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = delete conn, <%= schema.route_helper %>_path(conn, :delete, <%= schema.singular %>)
    assert redirected_to(conn) == <%= schema.route_helper %>_path(conn, :index)
    assert_error_sent 404, fn ->
      get conn, <%= schema.route_helper %>_path(conn, :show, <%= schema.singular %>)
    end
  end
end
