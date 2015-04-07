defmodule <%= application_module %>.PageControllerTest do
  use <%= application_module %>.ConnCase

  test "GET /" do
    conn = get conn(), "/"
    assert conn.resp_body =~ "Welcome to Phoenix!"
  end
end
