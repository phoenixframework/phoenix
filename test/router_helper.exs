defmodule RouterHelper do
  @moduledoc """
  Conveniences for testing routers and controllers.

  Must not be used to test endpoints as it does some
  pre-processing (like fetching params) which could
  skew endpoint tests.
  """

  import Plug.Test
  import ExUnit.CaptureIO

  @session Plug.Session.init(
    store: :cookie,
    key: "_app",
    encryption_salt: "yadayada",
    signing_salt: "yadayada"
  )

  defmacro __using__(_) do
    quote do
      use Plug.Test
      import RouterHelper
    end
  end

  def with_session(conn) do
    conn
    |> Map.put(:secret_key_base, String.duplicate("abcdefgh", 8))
    |> Plug.Session.call(@session)
    |> Plug.Conn.fetch_session()
  end

  def call(router, verb, path, params \\ nil, headers \\ []) do
    conn = conn(verb, path, params, headers) |> Plug.Conn.fetch_query_params
    router.call(conn, router.init([]))
  end

  def action(controller, verb, action, params \\ nil, headers \\ []) do
    conn = conn(verb, "/", params, headers) |> Plug.Conn.fetch_query_params
    controller.call(conn, controller.init(action))
  end

  def capture_log(fun) do
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  end
end
