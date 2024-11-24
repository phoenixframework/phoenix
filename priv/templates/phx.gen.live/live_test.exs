defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest
  import <%= inspect(context.module) %>Fixtures

  @invalid_attrs %{<%= Mix.Phoenix.TestData.live_invalid_attrs(schema) %>
  }

  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = <%= schema.singular %>_fixture()
    %{<%= schema.singular %>: <%= schema.singular %>}
  end

  describe "Index" do
    setup [:create_<%= schema.singular %>]

    test "lists all <%= schema.plural %>", %{conn: conn<%= if html_assertion_field do %>, <%= schema.singular %>: <%= schema.singular %><% end %>} do
      {:ok, _index_live, html} = live(conn, ~p"<%= schema.route_prefix %>")

      assert html =~ "Listing <%= schema.human_plural %>"<%= if html_assertion_field do %>
      assert html =~ <%= schema.singular %>.<%= html_assertion_field.name %><% end %>
    end

    test "saves new <%= schema.singular %>", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"<%= schema.route_prefix %>")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New <%= schema.human_singular %>")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/new")

      assert render(form_live) =~ "New <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.TestData.live_required_attr_message() %>"

<%= Mix.Phoenix.TestData.live_action_attrs_with_references(schema, :create) %>

      assert {:ok, index_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>")

      html = render(index_live)
      assert html =~ "<%= schema.human_singular %> created successfully"<%= if html_assertion_field do %>
      assert html =~ <%= html_assertion_field.create_value %><% end %>
    end

    test "updates <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, _html} = live(conn, ~p"<%= schema.route_prefix %>")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#<%= schema.plural %>-#{<%= schema.singular %>.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}/edit")

      assert render(form_live) =~ "Edit <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.TestData.live_required_attr_message() %>"

<%= Mix.Phoenix.TestData.live_action_attrs_with_references(schema, :update) %>

      assert {:ok, index_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>")

      html = render(index_live)
      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if html_assertion_field do %>
      assert html =~ <%= html_assertion_field.update_value %><% end %>
    end

    test "deletes <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, _html} = live(conn, ~p"<%= schema.route_prefix %>")

      assert index_live |> element("#<%= schema.plural %>-#{<%= schema.singular %>.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#<%= schema.plural %>-#{<%= schema.singular %>.id}")
    end
  end

  describe "Show" do
    setup [:create_<%= schema.singular %>]

    test "displays <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, _show_live, html} = live(conn, ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}")

      assert html =~ "Show <%= schema.human_singular %>"<%= if html_assertion_field do %>
      assert html =~ <%= schema.singular %>.<%= html_assertion_field.name %><% end %>
    end

    test "updates <%= schema.singular %> and returns to show", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, show_live, _html} = live(conn, ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}/edit?return_to=show")

      assert render(form_live) =~ "Edit <%= schema.human_singular %>"

      assert form_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "<%= Mix.Phoenix.TestData.live_required_attr_message() %>"

<%= Mix.Phoenix.TestData.live_action_attrs_with_references(schema, :update) %>

      assert {:ok, show_live, _html} =
               form_live
               |> form("#<%= schema.singular %>-form", <%= schema.singular %>: update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/#{<%= schema.singular %>}")

      html = render(show_live)
      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if html_assertion_field do %>
      assert html =~ <%= html_assertion_field.update_value %><% end %>
    end
  end
end
