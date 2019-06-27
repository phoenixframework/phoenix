defmodule Mix.Tasks.Local.Phx do
  use Mix.Task

  @shortdoc "Updates the Phoenix project generator locally"

  @moduledoc """
  Updates the Phoenix project generator locally.

      mix local.phx

  Accepts the same command line options as `archive.install hex phx_new`.

  *Note: Older versions of this task (up to and including 1.4.0) do not fetch
  the latest version from hex.  If your phx_new archive is older than 1.4, it's
  necessary to call `mix archive.install hex phx_new` manually at least once.*
  """
  def run(args) do
    Mix.Task.run("archive.install", ["hex", "phx_new" | args])
  end
end
