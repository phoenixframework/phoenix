defmodule Phoenix.Plugs.RouterLogger do
  import Phoenix.Controller.Connection
  require Logger

  @moduledoc """
  Plug to handle request logging at the router level

  Includes basic request logging of HTTP method and conn.path_info
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Plug.Conn.register_before_send(conn, fn (conn) -> 
      Logger.debug fn ->
        {_status, content_type} = response_content_type(conn)
        ["Processing by ", inspect(controller_module(conn)), ?., Atom.to_string(action_name(conn)), ?\n,
          "  Accept: ", content_type, ?\n,
          "  Parameters: ", inspect(conn.params), ?\n]
      end
      conn
    end)
  end
end
