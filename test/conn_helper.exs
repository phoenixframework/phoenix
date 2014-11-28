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
    router.call(conn(verb, path, params, headers), router.init([]))
  end

  def action(controller, verb, action, params \\ nil, headers \\ []) do
    controller.call(conn(verb, "/", params, headers), controller.init(action))
  end

  def capture_log(fun) do
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  end
end
