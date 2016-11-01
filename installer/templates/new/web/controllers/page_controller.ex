defmodule <%= app_module %>.PageController do
  use <%= app_module %>.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
