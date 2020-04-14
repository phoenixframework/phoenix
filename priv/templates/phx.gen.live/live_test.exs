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

  describe "index" do
    setup [:create_<%= schema.singular %>]

    test "lists all <%= schema.plural %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))
      connected_html = render(index_live)

      assert disconnected_html =~ "Listing <%= schema.human_plural %>"
      assert connected_html =~ "Listing <%= schema.human_plural %>"

      <%= if schema.string_attr do %>assert disconnected_html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
      <%= if schema.string_attr do %>assert connected_html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
    end

    test "renders new <%= schema.singular %> form", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, index_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :new))
      connected_html = render(index_live)

      <%= if schema.string_attr do %>assert disconnected_html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
      <%= if schema.string_attr do %>assert connected_html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
      assert disconnected_html =~ "New <%= schema.human_singular %>"
      assert connected_html =~ "New <%= schema.human_singular %>"
    end
  end

  describe "show" do
    setup [:create_<%= schema.singular %>]

    test "shows <%= schema.singular %>", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, show_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :show, <%= schema.singular %>))
      connected_html = render(show_live)

      assert disconnected_html =~ "Show <%= schema.human_singular %>"
      assert connected_html =~ "Show <%= schema.human_singular %>"
    end

    test "renders edit <%= schema.singular %> form", %{conn: conn, <%= schema.singular %>: <%= schema.singular %>} do
      {:ok, show_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :edit, <%= schema.singular %>))
      assert disconnected_html =~ "Edit <%= schema.human_singular %>"
      assert render(show_live) =~ "Edit <%= schema.human_singular %>"
      <%= if schema.string_attr do %>assert disconnected_html =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>
      <%= if schema.string_attr do %>assert render(show_live) =~ <%= schema.singular %>.<%= schema.string_attr %><% end %>

      assert render_submit([show_live, "form"], "save", %{"<%= schema.singular %>" => @invalid_attrs}) =~
               "Edit <%= schema.human_singular %>"

      <%= if schema.string_attr do %>assert {:error, {:redirect, path}} =
               render_submit([show_live, "form"], "save", %{"<%= schema.singular %>" => @update_attrs})

      {:ok, _show_live, disconnected_html} = live(conn, path)
      assert disconnected_html =~ "some updated <%= schema.string_attr %>"<% else %>
      assert {:error, {:redirect, _path}} =
               render_submit([show_live, "form-#{<%= schema.singular %>.id}"], "save", %{"<%= schema.singular %>" => @update_attrs})<%end %>
    end
  end
end
