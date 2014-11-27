defmodule Phoenix.ControllerLoggerTest do
  use ExUnit.Case
  use ConnHelper

  defmodule LoggerController do
    use Phoenix.Controller
    plug :action
    def index(conn, _params), do: text(conn, "index")
  end

  test "logs controller, action, format and parameters" do
    {_conn, [header, parameters, pipeline]} = capture_log fn ->
      conn = conn(:get, "/", foo: "bar", format: "html")
             |> fetch_params
             |> put_private(:phoenix_pipelines, [:browser])
      LoggerController.call(conn, LoggerController.init(:index))
    end
    assert header =~ "[debug] Processing by Phoenix.ControllerLoggerTest.LoggerController.index/2"
    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
    assert pipeline =~  "Pipeline: [:browser]"
  end
end
