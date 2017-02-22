defmodule Mix.Tasks.Local.Phoenix do
  use Mix.Task

  @url "https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez"
  @shortdoc "Updates Phoenix locally"

  @moduledoc """
  Updates Phoenix locally.

      mix local.phoenix

  Accepts the same command line options as `archive.install`.
  """
  def run(args) do
    Mix.Task.run "archive.install", [@url | args]
  end
end
