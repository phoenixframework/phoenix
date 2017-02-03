defmodule <%= inspect context.module %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  alias <%= inspect context.module %>

  @valid_attrs <%= inspect schema.params.default %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.default, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>, attrs \\ @valid_attrs) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(attrs)
    <%= schema.singular %>
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= schema.singular %>_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing <%= schema.human_plural %>"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, <%= schema.singular %>_path(conn, :new)
    assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
  end

  test "creates <%= schema.singular %> and redirects when data is valid", %{conn: conn} do
    <%= schema.singular %>_params = %{@valid_attrs | <%= schema.params.default_key %>: <%= inspect Mix.Phoenix.Schema.default_param(schema, :create) %>}
    conn = post conn, <%= schema.singular %>_path(conn, :create), <%= schema.singular %>: <%= schema.singular %>_params
    assert redirected_to(conn) == <%= schema.singular %>_path(conn, :index)

    conn = get conn, <%= schema.singular %>_path(conn, :index)
    assert html_response(conn, 200) =~ <%= inspect Mix.Phoenix.Schema.default_param(schema, :create) %>
  end

  test "does not create <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, <%= schema.singular %>_path(conn, :create), <%= schema.singular %>: @invalid_attrs
    assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
  end

  test "shows chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = get conn, <%= schema.singular %>_path(conn, :show, <%= schema.singular %>)
    assert html_response(conn, 200) =~ "Show <%= schema.human_singular %>"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, <%= schema.singular %>_path(conn, :show, <%= inspect schema.sample_id %>)
    end
  end

  test "renders form for editing chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = get conn, <%= schema.singular %>_path(conn, :edit, <%= schema.singular %>)
    assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"
  end

  test "updates chosen <%= schema.singular %> and redirects when data is valid", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    <%= schema.singular %>_params = %{@valid_attrs | <%= schema.params.default_key %>: <%= inspect Mix.Phoenix.Schema.default_param(schema, :update) %>}
    conn = put conn, <%= schema.singular %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: <%= schema.singular %>_params
    assert redirected_to(conn) == <%= schema.singular %>_path(conn, :show, <%= schema.singular %>)

    conn = get conn, <%= schema.singular %>_path(conn, :show, <%= schema.singular %>)
    assert html_response(conn, 200) =~ <%= inspect Mix.Phoenix.Schema.default_param(schema, :update) %>
  end

  test "does not update chosen <%= schema.singular %> and renders errors when data is invalid", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = put conn, <%= schema.singular %>_path(conn, :update, <%= schema.singular %>), <%= schema.singular %>: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"

    updated_<%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
    assert :eq = NaiveDateTime.compare(updated_<%= schema.singular %>.updated_at, <%= schema.singular %>.updated_at)
  end

  test "deletes chosen <%= schema.singular %>", %{conn: conn} do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    conn = delete conn, <%= schema.singular %>_path(conn, :delete, <%= schema.singular %>)
    assert redirected_to(conn) == <%= schema.singular %>_path(conn, :index)
    assert_error_sent 404, fn ->
      get conn, <%= schema.singular %>_path(conn, :show, <%= schema.singular %>)
    end
  end
end
