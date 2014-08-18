defmodule Phoenix.Plugs.CodeReloader do

  def init(opts), do: opts

  def call(conn, _opts) do
    if Code.ensure_loaded?(Mix.Task) do
      ensure_views_recompiled
      Mix.Task.reenable "compile.elixir"
      Mix.Task.run "compile.elixir", ["web"]
    else
      raise """
      If you want to use the code reload plug in production or inside an escript,
      add :mix to your list of dependencies or disable code reloading"
      """
    end

    conn
  end

  # TODO: Fix this hack
  defp ensure_views_recompiled do
    System.cmd("touch", ["web/views.ex"])
  end
end

