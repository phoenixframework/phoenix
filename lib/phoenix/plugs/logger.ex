defmodule Phoenix.Plugs.Logger do

  def init(opts), do: opts

  def call(conn, _) do
    IO.puts "#{conn.method}: #{inspect conn.path_info}"

    conn
  end
end
