defmodule Phoenix.Plugs.SessionFetcher do
  alias Plug.Conn

  @moduledoc """
  Plug to fetch Conn Session

  ## Examples

      plug Phoenix.Plugs.SessionFetcher

  """
  def init(opts), do: opts

  def call(conn, _), do: Conn.fetch_session(conn)
end
