defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [ app: :phoenix,
      version: "0.0.1",
      elixir: "~> 0.12.1",
      deps: deps ]
  end

  def application do
    [
      mod: { Phoenix, [] },
      applications: [:cowboy, :plug]
    ]
  end

  defp deps do
    [
      {:cowboy, github: "extend/cowboy"},
      {:plug, github: "elixir-lang/plug"},
      {:inflex, github: "nurugger07/inflex"}
    ]
  end
end
