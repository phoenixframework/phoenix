defmodule Phoenix.Plugs.CodeReloader do
  alias Phoenix.Config

  def init(opts), do: opts

  def call(conn, from: module) do
    reload!(Config.for(module).plugs[:code_reload])

    conn
  end

  defp reload!(true) do
    Mix.Task.reenable "compile.elixir"
    Mix.Task.run "compile.elixir"
  end
  defp reload!(_), do: :noop
end
