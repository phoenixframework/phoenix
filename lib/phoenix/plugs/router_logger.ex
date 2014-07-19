defmodule Phoenix.Plugs.RouterLogger do

  def init(opts), do: opts

  def call(conn, level) do
    log(conn, level)

    conn
  end

  defp log(conn, level) when level in [:debug, :info, :error] do
    IO.puts "#{conn.method}: #{inspect conn.path_info}"
  end
  defp log(_conn, _), do: nil
end
