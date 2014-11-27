defmodule Phoenix.ControllerLoggerTest do
  use ExUnit.Case
  use ConnHelper

  defmodule LoggerController do
    use Phoenix.Controller
    plug :action
    def index(conn, _params), do: text(conn, "index")
  end

  test "logs controller, action, format and parameters" do
    {_conn, [header, parameters]} = call_controller_with_params(foo: "bar", format: "html")
    assert header =~ "[debug] Processing by Phoenix.ControllerLoggerTest.LoggerController.index/2"
    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"format\" => \"html\"}"
  end

  test "filter parameter" do
    filter_parameters = Application.get_env(:phoenix, :filter_parameters)
    try do
      Application.put_env(:phoenix, :filter_parameters, filter_parameters ++ ["Secret"])
      {_conn, [_, parameters]} = call_controller_with_params(
        password: "should_not_be_show", Secret: "should_not_be_show"
      )
      assert parameters =~ "Parameters: %{\"Secret\" => \"FILTERED\", \"password\" => \"FILTERED\"}"
    after
      Application.put_env(:phoenix, :filter_parameters, filter_parameters)
    end
  end

  test "filter parameter when a Map has secret key" do
    {_conn, [_, parameters]} = call_controller_with_params(
      foo: "bar", map: %{ password: "should_not_be_show" }
    )
    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"map\" => %{\"password\" => \"FILTERED\"}}"
  end

  test "filter parameter when a List has a Map" do
    {_conn, [_, parameters]} = call_controller_with_params(
      foo: "bar", list: [ %{ password: "should_not_be_show"} ]
    )
    assert parameters =~ "Parameters: %{\"foo\" => \"bar\", \"list\" => [%{\"password\" => \"FILTERED\"}]}"
  end

  defp call_controller_with_params(params) do
    capture_log fn ->
      conn = conn(:get, "/", params) |> fetch_params
      LoggerController.call(conn, LoggerController.init(:index))
    end
  end
end
