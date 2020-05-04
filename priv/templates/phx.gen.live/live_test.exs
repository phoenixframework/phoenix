defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LiveTest do
  use <%= inspect context.web_module %>.ConnCase

  import Phoenix.LiveViewTest

  alias <%= inspect context.module %>

  @create_attrs <%= inspect schema.params.create %>
  @update_attrs <%= inspect schema.params.update %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  defp fixture(:<%= schema.singular %>) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@create_attrs)
    <%= schema.singular %>
  end

  defp create_<%= schema.singular %>(_) do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    %{<%= schema.singular %>: <%= schema.singular %>}
  end

  describe "Index" do
    setup [:create_<%= schema.singular %>]

    test "lists all <%= schema.plural %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, _index_live, html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert html =~ "Listing <%= schema.human_plural %>"<%= if schema.string_attr do %>
      assert html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
    end

    test "saves new <%= schema.singular %>", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert index_live |> element("a", "New <%= schema.human_singular %>") |> render_click() =~
               "New <%= schema.human_singular %>"

      assert_patch(index_live, Routes.<%= schema.route_helper %>_index_path(conn, :new))

      assert index_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "can&apos;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert html =~ "<%= schema.human_singular %> created successfully"<%= if schema.string_attr do %>
      assert html =~ "some <%= schema.string_attr %>"<% end %>
    end

    test "updates <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, _html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert index_live |> element("#<%= schema.singular %>-#{<%= schema.singular %>.id} a", "Edit") |> render_click() =~
               "Edit <%= schema.human_singular %>"

      assert_patch(index_live, Routes.<%= schema.route_helper %>_index_path(conn, :edit, <%= schema.singular %>))

      assert index_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "can&apos;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if schema.string_attr do %>
      assert html =~ "some updated <%= schema.string_attr %>"<% end %>
    end

    test "deletes <%= schema.singular %> in listing", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, _html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))

      assert index_live |> element("#<%= schema.singular %>-#{<%= schema.singular %>.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#<%= schema.singular %>-#{<%= schema.singular %>.id}")
    end
  end

  describe "Show" do
    setup [:create_<%= schema.singular %>]

    test "displays <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, _show_live, html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :show, <%= schema.singular %>))

      assert html =~ "Show <%= schema.human_singular %>"<%= if schema.string_attr do %>
      assert html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
    end

    test "updates <%= schema.singular %> within modal", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, show_live, _html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :show, <%= schema.singular %>))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit <%= schema.human_singular %>"

      assert_patch(show_live, Routes.<%= schema.route_helper %>_show_path(conn, :edit, <%= schema.singular %>))

      assert show_live
             |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @invalid_attrs)
             |> render_change() =~ "can&apos;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#<%= schema.singular %>-form", <%= schema.singular %>: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.<%= schema.route_helper %>_show_path(conn, :show, <%= schema.singular %>))

      assert html =~ "<%= schema.human_singular %> updated successfully"<%= if schema.string_attr do %>
      assert html =~ "some updated <%= schema.string_attr %>"<% end %>
    end
  end
end
