defmodule <%= @web_namespace %>.PageController do
  use <%= @web_namespace %>, :controller

  plug :put_layout, false when action in [:home]

  def home(conn, _params) do
    render(conn, "home.html")
  end
end
