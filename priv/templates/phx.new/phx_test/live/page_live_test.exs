defmodule <%= @web_namespace %>.PageLiveTest do
  use <%= @web_namespace %>.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    conn = get(conn, ~p"/")
    disconnected_html = html_response(conn, 200)
    {:ok, _live, connected_html} = live(conn)

    assert disconnected_html =~ "Welcome to Phoenix!"
    assert connected_html =~ "Welcome to Phoenix!"
  end
end
