defmodule Phoenix.ControllerLoggerTest do
  use ExUnit.Case, async: false
  use ConnHelper

  defmodule LoggerController do
    use Phoenix.Controller
    def index(conn, _params), do: text(conn, "index")
  end

  defmodule Router do
    use Phoenix.Router
    get "/", LoggerController, :index
  end

  test "verify logger" do
    {_conn, [_plug_log, header, accept, parameters, _plug_log_2]} = simulate_request_with_logging(Router, :get, "/")
    assert String.contains?(header, "[debug] Processing by Phoenix.ControllerLoggerTest.LoggerController.index")
    assert accept == "  Accept: text/html"
    assert parameters == "  Parameters: %{}"
  end
end
