defmodule <%= web_namespace %>.PageControllerTest do
  use <%= web_namespace %>.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
