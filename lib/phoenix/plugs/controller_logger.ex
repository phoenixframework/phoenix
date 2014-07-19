defmodule Phoenix.Plugs.ControllerLogger do
  import Phoenix.Controller.Connection

  @moduledoc """
  Plug to handle request logging at the controller level

  Includes controller, action, accept headers, and params info for :debug level
  """

  def init(opts), do: opts

  def call(conn, level) do
    log(conn, level)

    conn
  end

  defp log(conn, :debug) do
    IO.puts """
      controller: #{controller_module(conn)}
      action:     #{action_name(conn)}
      accept:     #{response_content_type(conn)}
      parameters: #{inspect conn.params}
    """
  end
  defp log(_conn, _), do: nil
end
