defmodule RouterHelper do
  import Plug.Test
  import ExUnit.CaptureIO

  defmacro __using__(_) do
    quote do
      use Plug.Test
      import RouterHelper
    end
  end

  def call(router, verb, path, params \\ nil, headers \\ []) do
    router.call(conn(verb, path, params, headers), [])
  end

  def action(controller, verb, action, params \\ nil, headers \\ []) do
    controller.call(conn(verb, "/", params, headers), action)
  end

  # TODO: Avoid capture_log does not allow us to run tests concurrently.
  # Always call it explicitly instead of by default.
  def simulate_request(router, http_method, path) do
    {conn, _} = capture_log fn ->
      conn = conn(http_method, path)
      router.call(conn, [])
    end
    conn
  end

  def simulate_request_with_logging(router, http_method, path) do
    capture_log fn ->
      conn = conn(http_method, path)
      router.call(conn, [])
    end
  end

  def capture_log(fun) do
    data = capture_io(:user, fn ->
      Process.put(:capture_log, fun.())
      Logger.flush()
    end) |> String.split("\n", trim: true)
    {Process.get(:capture_log), data}
  end
end
