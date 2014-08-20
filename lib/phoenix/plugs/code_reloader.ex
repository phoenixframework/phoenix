defmodule Phoenix.Plugs.CodeReloader do

  def init(opts), do: opts

  def call(conn, _opts) do
    Phoenix.CodeReloader.reload!
    conn
  end
end

