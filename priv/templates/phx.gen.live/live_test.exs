defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LiveTest do
  use <%= inspect context.web_module %>.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  describe "index" do
    test "lists all <%= schema.plural %>", %{conn: conn} do
      {:ok, index_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :index))
      assert disconnected_html =~ "Listing <%= schema.human_plural %>"
      assert render(index_live) =~ "Listing <%= schema.human_plural %>"
    end

    test "renders new <%= schema.singular %> form", %{conn: conn} do
      {:ok, index_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_index_path(conn, :new))
      assert disconnected_html =~ "New <%= schema.human_singular %>"
      assert render(index_live) =~ "New <%= schema.human_singular %>"
    end
  end

  describe "show" do
    test "shows <%= schema.singular %>", %{conn: conn} do
      {:ok, show_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :show))
      assert disconnected_html =~ "Listing <%= schema.human_plural %>"
      assert render(show_live) =~ "Listing <%= schema.human_plural %>"
    end

    test "renders new <%= schema.singular %> form", %{conn: conn} do
      {:ok, show_live, disconnected_html} = live(conn, Routes.<%= schema.route_helper %>_show_path(conn, :new))
      assert disconnected_html =~ "New <%= schema.human_singular %>"
      assert render(show_live) =~ "New <%= schema.human_singular %>"
    end
  end
end
