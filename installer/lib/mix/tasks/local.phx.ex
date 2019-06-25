defmodule Mix.Tasks.Local.Phx do
  use Mix.Task

  @url "https://github.com/phoenixframework/archives/raw/master/phx_new.ez"
  @shortdoc "Updates the Phoenix project generator locally"

  @moduledoc """
  Updates the Phoenix project generator locally.

      mix local.phx

  Accepts the same command line options as `archive.install`. `phx.local` is no longer supported after 1.3. To update the Phoenix project generator, please use `mix archive.install hex phx_new` instead.
  """
  def run(args) do
    Mix.Task.run("archive.install", [@url | args])
  end
end
