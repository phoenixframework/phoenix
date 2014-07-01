defmodule Phoenix.Plugs.Logger do
  alias Phoenix.Config

  def init(opts), do: opts

  def call(conn, level) do
    log(conn, level)

    conn
  end

  defp log(conn, :debug) do
    IO.puts "#{conn.method}: #{inspect conn.path_info}"
  end
  defp log(_conn, _), do: nil
end
