defmodule Phoenix.Plugs.ParamsFetcher do
  alias Plug.Conn
  import Phoenix.Controller.Connection

  @moduledoc """
  Plug to fetch Conn params and merge any named parameters from route definition

  Plugged automatically by Phoenix.Controller

  ## Examples

      plug Phoenix.Plugs.ParamsFetcher

  """
  def init(opts), do: opts

  def call(conn, _), do: fetch(conn)

  def fetch(conn) do
    conn = Conn.fetch_params(conn)
    put_in conn.params, Dict.merge(conn.params, named_params(conn))
  end
end
