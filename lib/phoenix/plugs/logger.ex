defmodule Phoenix.Plugs.Logger do
  import Phoenix.Controller.Connection

  def init(opts), do: opts

  def call(conn, level) do
    log(conn, level)

    conn
  end

  defp log(conn, :debug) do
    IO.puts """
    #{conn.method}: #{inspect conn.path_info}
      controller: #{controller_module(conn)}
      action:     #{action_name(conn)}
      accept:     #{response_content_type(conn)}

      parameters: #{inspect conn.params}

    """
  end
  defp log(_conn, _), do: nil
end
