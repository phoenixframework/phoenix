defmodule RouterHelper do
  @moduledoc """
  Conveniences for testing routers and controllers.

  Must not be used to test endpoints as it does some
  pre-processing (like fetching params) which could
  skew endpoint tests.
  """

  import Plug.Test

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

  def call(router, verb, path, params \\ nil, script_name \\ []) do
    verb
    |> conn(path, params)
    |> Plug.Conn.fetch_query_params
    |> Map.put(:script_name, script_name)
    |> router.call(router.init([]))
  end

  def action(controller, verb, action, params \\ nil) do
    conn = conn(verb, "/", params) |> Plug.Conn.fetch_query_params
    controller.call(conn, controller.init(action))
  end
end
