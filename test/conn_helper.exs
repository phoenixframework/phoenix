defmodule ConnHelper do
  import Plug.Test
  import ExUnit.CaptureIO

  defmacro __using__(_) do
    quote do
      use Plug.Test
      import ConnHelper
    end
  end

  def call(router, verb, path, params \\ nil, headers \\ []) do
    flush_already_sent()
    router.call(conn(verb, path, params, headers), router.init([]))
  end

  def action(controller, verb, action, params \\ nil, headers \\ []) do
    flush_already_sent()
    controller.call(conn(verb, "/", params, headers), controller.init(action))
  end

  def capture_log(fun) do
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  end

  @already_sent {:plug_conn, :sent}

  defp flush_already_sent() do
    receive do
      @already_sent -> :ok
    after
      0 -> :ok
    end
  end
end
