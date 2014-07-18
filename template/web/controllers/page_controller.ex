defmodule <%= application_module %>.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index"
  end
end
