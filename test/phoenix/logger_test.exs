defmodule Phoenix.LoggerTest do
  use ExUnit.Case, async: true
  use RouterHelper

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
               %{
                 "foo" => %{"bar" => "[FILTERED]", "baz" => "[FILTERED]"},
                 "ids" => ["[FILTERED]", "[FILTERED]"]
               }
    end
  end

  describe "telemetry" do
    def log_level(conn) do
      case conn.path_info do
        [] -> :debug
        ["warn" | _] -> :warning
        ["error" | _] -> :error
        ["false" | _] -> false
        _ -> :info
      end
    end

    test "invokes log level callback from Plug.Telemetry" do
      opts =
        Plug.Telemetry.init(
          event_prefix: [:phoenix, :endpoint],
          log: {__MODULE__, :log_level, []}
        )

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/"), opts)
             end) =~ "[debug] GET /"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/warn"), opts)
             end) =~ ~r"\[warn(ing)?\]  ?GET /warn"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/error/404"), opts)
             end) =~ "[error] GET /error/404"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/any"), opts)
             end) =~ "[info] GET /any"
    end

    test "invokes log level from Plug.Telemetry" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               opts = Plug.Telemetry.init(event_prefix: [:phoenix, :endpoint], log: :error)
               Plug.Telemetry.call(conn(:get, "/"), opts)
             end) =~ "[error] GET /"
    end
  end
end
