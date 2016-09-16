defmodule <%= app_module %>.Web.PageController do
  use <%= app_module %>.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
