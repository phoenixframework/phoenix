defmodule RouterHelper do
  @moduledoc """
  Conveniences for testing routers and controllers.

  Must not be used to test endpoints.
  """

  import Plug.Test
  import ExUnit.CaptureIO

  defmacro __using__(_) do
    quote do
      use Plug.Test
      import RouterHelper
    end
  end

  def call(router, verb, path, params \\ nil, headers \\ []) do
    conn = conn(verb, path, params, headers) |> Plug.Conn.fetch_params
    router.call(conn, router.init([]))
  end

  def action(controller, verb, action, params \\ nil, headers \\ []) do
    conn = conn(verb, "/", params, headers) |> Plug.Conn.fetch_params
    controller.call(conn, controller.init(action))
  end

  def capture_log(fun) do
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  end
end
