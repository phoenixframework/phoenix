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

  describe "filter_values/2 with discard strategy" do
    test "in top level map" do
      values = %{"foo" => "bar", "password" => "should_not_show"}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{"foo" => "bar", "password" => "[FILTERED]"}
    end

    test "when a map has secret key" do
      values = %{"foo" => "bar", "map" => %{"password" => "should_not_show"}}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{"foo" => "bar", "map" => %{"password" => "[FILTERED]"}}
    end

    test "when a list has a map with secret" do
      values = %{"foo" => "bar", "list" => [%{"password" => "should_not_show"}]}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{"foo" => "bar", "list" => [%{"password" => "[FILTERED]"}]}
    end

    test "does not filter structs" do
      values = %{"foo" => "bar", "file" => %Plug.Upload{}}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{"foo" => "bar", "file" => %Plug.Upload{}}

      values = %{"foo" => "bar", "file" => %{__struct__: "s"}}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{"foo" => "bar", "file" => %{:__struct__ => "s"}}
    end

    test "does not fail on atomic keys" do
      values = %{:foo => "bar", "password" => "should_not_show"}
      assert Phoenix.Logger.filter_values(values, ["password"]) ==
            %{:foo => "bar", "password" => "[FILTERED]"}
    end
  end

  describe "filter_values/2 with keep strategy" do
    test "discards values not specified in params" do
      values = %{"foo" => "bar", "password" => "abc123", "file" => %Plug.Upload{}}
      assert Phoenix.Logger.filter_values(values, {:keep, []}) ==
            %{"foo" => "[FILTERED]", "password" => "[FILTERED]", "file" => "[FILTERED]"}
    end

    test "keeps values that are specified in params" do
      values = %{"foo" => "bar", "password" => "abc123", "file" => %Plug.Upload{}}
      assert Phoenix.Logger.filter_values(values, {:keep, ["foo", "file"]}) ==
            %{"foo" => "bar", "password" => "[FILTERED]", "file" => %Plug.Upload{}}
    end

    test "keeps all values under keys that are kept" do
      values = %{"foo" => %{"bar" => 1, "baz" => 2}}
      assert Phoenix.Logger.filter_values(values, {:keep, ["foo"]}) ==
            %{"foo" => %{"bar" => 1, "baz" => 2}}
    end

    test "only filters leaf values" do
      values = %{"foo" => %{"bar" => 1, "baz" => 2}, "ids" => [1, 2]}
      assert Phoenix.Logger.filter_values(values, {:keep, []}) ==
            %{"foo" => %{"bar" => "[FILTERED]", "baz" => "[FILTERED]"},
              "ids" => ["[FILTERED]", "[FILTERED]"]}
    end
  end

  test "logs phoenix_channel_join as configured by the channel" do

    log = capture_log(fn ->
      socket = %Phoenix.Socket{private: %{log_join: :info}}
      Phoenix.Logger.phoenix_channel_join(:start, %{}, %{socket: socket, params: %{}})
    end)
    assert log =~ "JOIN"

    log = capture_log(fn ->
      socket = %Phoenix.Socket{private: %{log_join: false}}
      Phoenix.Logger.phoenix_channel_join(:start, %{}, %{socket: socket, params: %{}})
    end)
    assert log == ""
  end

  test "logs phoenix_channel_receive as configured by the channel" do
    log = capture_log(fn ->
      socket = %Phoenix.Socket{private: %{log_handle_in: :debug}}
      Phoenix.Logger.phoenix_channel_receive(:start, %{}, %{socket: socket, event: "e", params: %{}})
    end)
    assert log =~ "INCOMING"

    log = capture_log(fn ->
      socket = %Phoenix.Socket{private: %{log_handle_in: false}}
      Phoenix.Logger.phoenix_channel_receive(:start, %{}, %{socket: socket, event: "e", params: %{}})
    end)
    assert log == ""
  end


  defp action(conn) do
    LoggerController.call(conn, LoggerController.init(:index))
  end
end
