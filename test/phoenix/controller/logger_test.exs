defmodule Phoenix.Controller.LoggerTest do
  use ExUnit.Case
  use RouterHelper

  defmodule LoggerController do
    use Phoenix.Controller
    plug :action
    def index(conn, _params), do: text(conn, "index")
  end

  test "logs controller, action, format and parameters" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", format: "html")
      |> fetch_params
      |> put_private(:phoenix_pipelines, [:browser])
      |> action
    end
    assert output =~ "[debug] Processing by Phoenix.Controller.LoggerTest.LoggerController.index/2"
    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
    assert output =~ "Pipelines: [:browser]"
  end

  test "filter parameter" do
    filter_parameters = Application.get_env(:phoenix, :filter_parameters)

    try do
      Application.put_env(:phoenix, :filter_parameters, ["PASS"])

      output = capture_log fn ->
        conn(:get, "/", password: "should_show", PASS: "should_not_show")
        |> fetch_params
        |> action
      end

      assert output =~ "Parameters: %{\"PASS\" => \"[FILTERED]\", \"password\" => \"should_show\"}"
    after
      Application.put_env(:phoenix, :filter_parameters, filter_parameters)
    end
  end

  test "filter parameter when a map has secret key" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", map: %{password: "should_not_show"})
      |> fetch_params
      |> action
    end

    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"map\" => %{\"password\" => \"[FILTERED]\"}}"
  end

  test "filter parameter when a list has a map with secret" do
    output = capture_log fn ->
      conn(:get, "/", foo: "bar", list: [%{password: "should_not_show"}])
      |> fetch_params
      |> action
    end

    assert output =~ "Parameters: %{\"foo\" => \"bar\", \"list\" => [%{\"password\" => \"[FILTERED]\"}]}"
  end

  test "does not filter structs" do
    output = capture_log fn ->
      conn(:get, "/", %{foo: "bar", file: %Plug.Upload{}})
      |> fetch_params
      |> action
    end
    assert output =~ "Parameters: %{\"file\" => %Plug.Upload{content_type: nil, filename: nil, path: nil}, \"foo\" => \"bar\"}"

    output = capture_log fn ->
      conn(:get, "/", %{foo: "bar", file: %{__struct__: "s"}})
      |> fetch_params
      |> action
    end
    assert output =~ "Parameters: %{\"file\" => %{\"__struct__\" => \"s\"}, \"foo\" => \"bar\"}"
  end

  test "does not fail on atomic keys" do
    output = capture_log fn ->
      conn(:get, "/", %{password: "should_not_show"})
      |> fetch_params
      |> Map.update!(:params, &Dict.put(&1, :foo, "bar"))
      |> action
    end
    assert output =~ "Parameters: %{:foo => \"bar\", \"password\" => \"[FILTERED]\"}"
  end

  test "does not filter unfetched parameters" do
    output = capture_log fn ->
      conn(:get, "/", "{foo:bar}", headers: [{"content-type", "application/json"}])
      |> action
    end
    assert output =~ "Parameters: [UNFETCHED]"
  end

  defp action(conn) do
    LoggerController.call(conn, LoggerController.init(:index))
  end
end
