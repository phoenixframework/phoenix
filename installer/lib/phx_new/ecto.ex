defmodule Mix.Tasks.Phx.New.Ecto do
  use Mix.Task
  import Phx.New.Generator

  def run([path | _] = args) do
    unless in_umbrella?(path) do
      Mix.raise "the ecto task can only be run within an umbrella's apps directory"
    end

    Mix.Tasks.Phx.New.run(args, Mix.Tasks.Phx.New.App)
  end
end
