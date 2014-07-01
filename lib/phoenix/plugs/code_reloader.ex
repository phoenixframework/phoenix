defmodule Phoenix.Plugs.CodeReloader do

  def init(opts), do: opts

  def call(conn, _opts) do
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir"

    conn
  end
end
