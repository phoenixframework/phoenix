defmodule Phoenix.Controller.LoggerTest do
  use ExUnit.Case
  use ConnHelper

  defmodule LoggerController do
    use Phoenix.Controller
    plug :action
    def index(conn, _params), do: text(conn, "index")
  end

  test "logs controller, action, format and parameters" do
    {_conn, [header, parameters, pipeline]} = capture_log fn ->
      conn(:get, "/", foo: "bar", format: "html")
      |> fetch_params
      |> put_private(:phoenix_pipelines, [:browser])
      |> LoggerController.call(LoggerController.init(:index))
    end
    assert header =~ "[debug] Processing by Phoenix.Controller.LoggerTest.LoggerController.index/2"
    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
    assert pipeline =~  "Pipeline: [:browser]"
  end

  test "filter parameter" do
    filter_parameters = Application.get_env(:phoenix, :filter_parameters)
    try do
      Application.put_env(:phoenix, :filter_parameters, filter_parameters ++ ["Secret"])
      {_conn, [_, parameters, _pipeline]} = capture_log fn ->
        conn(:get, "/", password: "should_not_be_show", Secret: "should_not_be_show")
        |> fetch_params
        |> LoggerController.call(LoggerController.init(:index))
      end

      assert parameters =~ "Parameters: %{\"Secret\" => \"FILTERED\", \"password\" => \"FILTERED\"}"
    after
      Application.put_env(:phoenix, :filter_parameters, filter_parameters)
    end
  end

  test "filter parameter when a Map has secret key" do
    {_conn, [_, parameters, _pipeline]} = capture_log fn ->
      conn(:get, "/", foo: "bar", map: %{password: "should_not_be_show"})
      |> fetch_params
      |> LoggerController.call(LoggerController.init(:index))
    end

    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"map\" => %{\"password\" => \"FILTERED\"}}"
  end

  test "filter parameter when a List has a Map" do
    {_conn, [_, parameters, _pipeline]} = capture_log fn ->
      conn(:get, "/", foo: "bar", list: [%{ password: "should_not_be_show"}])
      |> fetch_params
      |> LoggerController.call(LoggerController.init(:index))
    end

    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"list\" => [%{\"password\" => \"FILTERED\"}]}"
  end
end
