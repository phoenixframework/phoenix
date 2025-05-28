defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect context.module %>Fixtures

  @create_attrs <%= Mix.Phoenix.to_text for {key, value} <- schema.params.create, into: %{}, do: {key, Mix.Phoenix.Schema.live_form_value(value)} %>
  @update_attrs <%= Mix.Phoenix.to_text for {key, value} <- schema.params.update, into: %{}, do: {key, Mix.Phoenix.Schema.live_form_value(value)} %>
  @invalid_attrs <%= Mix.Phoenix.to_text for {key, value} <- schema.params.create, into: %{}, do: {key, value |> Mix.Phoenix.Schema.live_form_value() |> Mix.Phoenix.Schema.invalid_form_value()} %><%= if scope do %>

  setup :<%= scope.test_setup_helper %>

  defp create_<%= schema.singular %>(%{scope: scope}) do
    <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
<% else %>
  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = <%= schema.singular %>_fixture()
<% end %>
    %{<%= schema.singular %>: <%= schema.singular %>}
  end

  describe "Index" do
    setup [:create_<%= schema.singular %>]

    test "lists all <%= schema.plural %>", <%= if schema.string_attr do %>%{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>}<% else %>%{conn: conn<%= test_context_scope %>}<% end %> do
      {:ok, _index_live, html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      assert html =~ "Listing <%= schema.human_plural %>"<%= if schema.string_attr do %>
      assert html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
    end

    test "saves new <%= schema.singular %>", %{conn: conn<%= test_context_scope %>} do
      {:ok, index_live, _html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New <%= schema.human_singular %>")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/new")

      assert render(form_live) =~ "New <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.Schema.failed_render_change_message(schema) %>"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      html = render(index_live)
      assert html =~ "<%= schema.human_singular %> created successfully"<%= if schema.string_attr do %>
      assert html =~ "some <%= schema.string_attr %>"<% end %>
    end

    test "updates <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      {:ok, index_live, _html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#<%= schema.plural %>-#{<%= schema.singular %>.<%= primary_key %>} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}/edit")

      assert render(form_live) =~ "Edit <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.Schema.failed_render_change_message(schema) %>"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      html = render(index_live)
      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if schema.string_attr do %>
      assert html =~ "some updated <%= schema.string_attr %>"<% end %>
    end

    test "deletes <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      {:ok, index_live, _html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>")

      assert index_live |> element("#<%= schema.plural %>-#{<%= schema.singular %>.<%= primary_key %>} a", "Delete") |> render_click()
      refute has_element?(index_live, "#<%= schema.plural %>-#{<%= schema.singular %>.<%= primary_key %>}")
    end
  end

  describe "Show" do
    setup [:create_<%= schema.singular %>]

    test "displays <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      {:ok, _show_live, html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")

      assert html =~ "Show <%= schema.human_singular %>"<%= if schema.string_attr do %>
      assert html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
    end

    test "updates <%= schema.singular %> and returns to show", %{conn: conn, <%= schema.singular %>: <%= schema.singular %><%= test_context_scope %>} do
      {:ok, show_live, _html} = live(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}/edit?return_to=show")

      assert render(form_live) =~ "Edit <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.Schema.failed_render_change_message(schema) %>"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= scope_param_route_prefix %><%= schema.route_prefix %>/#{<%= schema.singular %>}")

      html = render(show_live)
      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if schema.string_attr do %>
      assert html =~ "some updated <%= schema.string_attr %>"<% end %>
    end
  end
end
