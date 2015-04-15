defmodule <%= application_module %>.PageControllerTest do
  use <%= application_module %>.ConnCase

  test "GET /" do
    conn = get conn(), "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
