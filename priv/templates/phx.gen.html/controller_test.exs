defmodule <%= inspect schema.module %>ControllerTest do
  use <%= inspect context.base_module %>.ConnCase

  alias <%= inspect schema.module %>

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, <%= schema.singular %>_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing <%= schema.human_plural %>"
  end

  test "TODO" do
    flunk "TODO"
  end
end
