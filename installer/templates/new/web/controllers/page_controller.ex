defmodule <%= application_module %>.PageController do
  use <%= application_module %>.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
