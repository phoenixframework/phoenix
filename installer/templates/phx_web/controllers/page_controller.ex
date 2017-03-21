defmodule <%= web_namespace %>.PageController do
  use <%= web_namespace %>, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
