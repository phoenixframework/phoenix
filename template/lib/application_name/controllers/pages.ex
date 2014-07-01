defmodule <%= application_module %>.Controllers.Pages do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index"
  end
end
