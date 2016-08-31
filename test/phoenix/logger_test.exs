defmodule Phoenix.LoggerTest do
  use ExUnit.Case, async: true
  use RouterHelper
  import ExUnit.CaptureLog

  Application.put_env(:phoenix, __MODULE__.Endpoint, [
    server: false,
    secret_key_base: String.duplicate("abcdefgh", 8),
  ])

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    Endpoint.start_link()
    :ok
  end

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
      |> Endpoint.call([])
      |> put_private(:phoenix_pipelines, [:browser])
      |> action
    end
    assert output =~ "[debug] Processing with Phoenix.LoggerTest.LoggerController.index/2"
    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
    assert output =~ "Pipelines: [:browser]"
  end

  test "does not log when disabled" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", format: "html")
      |> fetch_query_params
      |> put_private(:phoenix_pipelines, [:browser])
      |> Endpoint.call([])
      |> NoLoggerController.call(NoLoggerController.init(:index))
    end
    assert output == ""
  end

  test "filter parameter" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", password: "should_not_show")
      |> fetch_query_params
      |> Endpoint.call([])
      |> action
    end

    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"password\" => \"[FILTERED]\"}"
  end

  test "does not filter unfetched parameters" do
    output = capture_log fn ->
      conn(:get, "/", "{foo:bar}")
      |> put_req_header("content-type", "application/json")
      |> Endpoint.call([])
      |> action
    end
    assert output =~ "Parameters: [UNFETCHED]"
  end

  test "filter_values" do
    assert Phoenix.Logger.filter_values(%{"foo" => "bar", "password" => "should_not_show"}, ["password"]) ==
           %{"foo" => "bar", "password" => "[FILTERED]"}
  end

  test "filter_values when a map has secret key" do
    assert Phoenix.Logger.filter_values(%{"foo" => "bar", "map" => %{"password" => "should_not_show"}}, ["password"]) ==
           %{"foo" => "bar", "map" => %{"password" => "[FILTERED]"}}
  end

  test "filter_values when a list has a map with secret" do
    assert Phoenix.Logger.filter_values(%{"foo" => "bar", "list" => [%{"password" => "should_not_show"}]}, ["password"]) ==
           %{"foo" => "bar", "list" => [%{"password" => "[FILTERED]"}]}
  end

  test "filter_values does not filter structs" do
    assert Phoenix.Logger.filter_values(%{"foo" => "bar", "file" => %Plug.Upload{}}, ["password"]) ==
           %{"foo" => "bar", "file" => %Plug.Upload{}}

    assert Phoenix.Logger.filter_values(%{"foo" => "bar", "file" => %{__struct__: "s"}}, ["password"]) ==
           %{"foo" => "bar", "file" => %{:__struct__ => "s"}}
  end

  test "filter_values does not fail on atomic keys" do
    assert Phoenix.Logger.filter_values(%{:foo => "bar", "password" => "should_not_show"}, ["password"]) ==
           %{:foo => "bar", "password" => "[FILTERED]"}
  end

  defp action(conn) do
    LoggerController.call(conn, LoggerController.init(:index))
  end
end
