defmodule Phoenix.Controller.LoggerTest do
  use ExUnit.Case, async: true
  use RouterHelper
  import ExUnit.CaptureLog

  defmodule LoggerController do
    use Phoenix.Controller
    def index(conn, _params), do: text(conn, "index")
  end

  defmodule NoLoggerController do
    use Phoenix.Controller, log: false
    def index(conn, _params), do: text(conn, "index")
  end

  test "logs controller, action, format and parameters" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", format: "html")
      |> fetch_query_params
      |> put_private(:phoenix_pipelines, [:browser])
      |> action
    end
    assert output =~ "[debug] Processing by Phoenix.Controller.LoggerTest.LoggerController.index/2"
    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
    assert output =~ "Pipelines: [:browser]"
  end

  test "does not log when disabled" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", format: "html")
      |> fetch_query_params
      |> put_private(:phoenix_pipelines, [:browser])
      |> NoLoggerController.call(NoLoggerController.init(:index))
    end
    assert output == ""
  end

  test "filter parameter" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", password: "should_not_show")
      |> fetch_query_params
      |> action
    end

    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"password\" => \"[FILTERED]\"}"
  end

  test "does not filter unfetched parameters" do
    output = capture_log fn ->
      conn(:get, "/", "{foo:bar}")
      |> put_req_header("content-type", "application/json")
      |> action
    end
    assert output =~ "Parameters: [UNFETCHED]"
  end

  defp action(conn) do
    LoggerController.call(conn, LoggerController.init(:index))
  end
end
