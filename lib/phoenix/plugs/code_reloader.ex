defmodule Phoenix.Plugs.CodeReloader do

  def init(opts), do: opts

  def call(conn, _) do
    reload!(Mix.env)

    conn
  end

  defp reload!(:dev), do: Mix.Tasks.Compile.Elixir.run([])
  defp reload!(_), do: :noop
end
