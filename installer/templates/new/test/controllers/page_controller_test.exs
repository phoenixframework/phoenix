defmodule <%= app_module %>.PageControllerTest do
  use <%= app_module %>.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
