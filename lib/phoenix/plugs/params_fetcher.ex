defmodule Phoenix.Plugs.ParamsFetcher do
  alias Plug.Conn

  @moduledoc """
  Plug to fetch Conn params and merge any named parameters from route definition

  Plugged automatically by Phoenix.Controller

  Examples

  plug Phoenix.Plugs.ParamsFetcher

  """
  def init(opts), do: opts

  def call(conn, _), do: fetch(conn)

  def fetch(conn) do
    conn = Conn.fetch_params(conn)
    named_params = Dict.get(conn.private, :phoenix_named_params, %{})
    put_in conn.params, Dict.merge(conn.params, named_params)
  end
end
