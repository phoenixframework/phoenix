defmodule Mix.Tasks.Local.Phx do
  use Mix.Task

  @url "https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez"
  @shortdoc "Updates the Phoenix project generator locally"

  @moduledoc """
  Updates the Phoenix project generator locally.

      mix local.phx

  Accepts the same command line options as `archive.install`.
  """
  def run(args) do
    Mix.Task.run "archive.install", [@url | args]
  end
end
