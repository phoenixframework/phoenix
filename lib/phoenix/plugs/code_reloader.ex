defmodule Phoenix.Plugs.CodeReloader do

  def init(opts), do: opts

  def call(conn, _) do
    reload!(Mix.env)

    conn
  end

  defp reload!(:dev) do
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir"
  end
  defp reload!(_), do: :noop
end
