defmodule <%= web_namespace %>.PageLiveTest do
  use <%= web_namespace %>.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconneted_html} = live(conn, "/")
    assert disconneted_html =~ "Welcome to Phoenix!"
    assert render(page_live) =~ "Welcome to Phoenix!"
  end
end
