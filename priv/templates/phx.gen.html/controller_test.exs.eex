defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ControllerTest do
  use <%= inspect context.web_module %>.ConnCase

  import <%= inspect context.module %>Fixtures

  @create_attrs <%= Mix.Phoenix.to_text schema.params.create %>
  @update_attrs <%= Mix.Phoenix.to_text schema.params.update %>
  @invalid_attrs <%= Mix.Phoenix.to_text (for {key, _} <- schema.params.create, into: %{}, do: {key, nil}) %><%= if scope do %>

  setup :<%= scope.test_setup_helper %><% end %>

  describe "index" do
    test "lists all <%= schema.plural %>", %{conn: conn<%= test_context_scope %>} do
      conn = get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")
      assert html_response(conn, 200) =~ "Listing <%= schema.human_plural %>"
    end
  end

  describe "new <%= schema.singular %>" do
    test "renders form", %{conn: conn<%= test_context_scope %>} do
      conn = get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/new")
      assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
    end
  end

  describe "create <%= schema.singular %>" do
    test "redirects to show when data is valid", %{conn: conn<%= test_context_scope %>} do
      conn = post(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>", <%= schema.singular %>: @create_attrs)

      assert %{<%= primary_key %>: <%= primary_key %>} = redirected_params(conn)
      assert redirected_to(conn) == ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= primary_key %>}"

      conn = get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= primary_key %>}")
      assert html_response(conn, 200) =~ "<%= schema.human_singular %> #{<%= primary_key %>}"
    end

    test "renders errors when data is invalid", %{conn: conn<%= test_context_scope %>} do
      conn = post(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>", <%= schema.singular %>: @invalid_attrs)
      assert html_response(conn, 200) =~ "New <%= schema.human_singular %>"
    end
  end

  describe "edit <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "renders form for editing chosen <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      conn = get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}/edit")
      assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"
    end
  end

  describe "update <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "redirects when data is valid", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      conn = put(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}", <%= schema.singular %>: @update_attrs)
      assert redirected_to(conn) == ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}"

      conn = get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")<%= if schema.string_attr do %>
      assert html_response(conn, 200) =~ <%= inspect Mix.Phoenix.Schema.default_param(schema, :update) %><% else %>
      assert html_response(conn, 200)<% end %>
    end

    test "renders errors when data is invalid", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      conn = put(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}", <%= schema.singular %>: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit <%= schema.human_singular %>"
    end
  end

  describe "delete <%= schema.singular %>" do
    setup [:create_<%= schema.singular %>]

    test "deletes chosen <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      conn = delete(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")
      assert redirected_to(conn) == ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>"

      assert_error_sent 404, fn ->
        get(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")
      end
    end
  end

<%= if scope do %>  defp create_<%= schema.singular %>(%{scope: scope}) do
    <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
<% else %>  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = <%= schema.singular %>_fixture()
<% end %>
    %{<%= schema.singular %>: <%= schema.singular %>}
  end
end
