defmodule Phoenix.Plugs.ControllerLogger do
  import Phoenix.Controller.Connection
  require Logger

  @moduledoc """
  Plug to handle request logging at the router level

  Includes basic request logging of HTTP method and conn.path_info
  """

  def init(opts), do: opts

  def call(conn, _level) do
    Logger.debug fn ->
      {_status, content_type} = response_content_type(conn)
      module = conn |> controller_module |> inspect
      action = conn |> action_name |> Atom.to_string

      ["Processing by ", module, ?., action, ?\n,
        "  Accept: ", content_type, ?\n,
        "  Parameters: ", inspect(conn.params)]
    end
    conn
  end
end
