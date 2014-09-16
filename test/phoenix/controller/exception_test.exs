defmodule Phoenix.Controller.ExceptionTest do
  use ExUnit.Case, async: false
  alias Phoenix.Controller
  import RouterHelper

  def conn_with_caught_exception(func) do
    try do
      func.()
    catch
      kind, err -> Controller.Connection.assign_error(%Plug.Conn{}, kind, err)
    end
  end

  test "from_conn returns :no_exception when no error has been caught" do
    assert Controller.Exception.from_conn(%Plug.Conn{}) == :no_exception
  end

  test "from_conn returns %Exception{} when error has been caught" do
    conn = conn_with_caught_exception fn -> raise "boom" end
    assert match?(%Controller.Exception{}, Controller.Exception.from_conn(conn))
  end

  test "from_conn returns %Exception{} with exception details" do
    conn = conn_with_caught_exception fn -> raise "boom" end
    exception = Controller.Exception.from_conn(conn)

    assert exception.status == 500
    assert exception.kind == :error
    assert exception.stacktrace
    assert exception.message == "boom"
  end

  test "log/1 logs the exception when caugt" do
    conn = conn_with_caught_exception fn -> raise "boom" end
    {_, log} = capture_log fn ->
      assert Controller.Exception.log(conn)
    end
    assert String.match?(to_string(log), ~r/\(RuntimeError\) boom/)
  end

  test "log/1 returns :no_exception when no exception has been caught" do
    {_, log} = capture_log fn ->
      assert Controller.Exception.log(%Plug.Conn{}) == :no_exception
    end
    assert to_string(log) == ""
  end
end
