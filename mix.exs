defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [ app: :phoenix,
      version: "0.0.1",
      elixir: "~> 0.12.4",
      deps: deps(Mix.env) ]
  end

  def application do
    [
      mod: { Phoenix, [] },
      applications: [:cowboy, :plug]
    ]
  end

  defp deps(:prod) do
    [
      {:cowboy, github: "extend/cowboy"},
      {:plug, github: "elixir-lang/plug"},
      {:inflex, github: "nurugger07/inflex"},
      {:ex_conf, github: "phoenixframework/ex_conf"}
    ]
  end

  defp deps(_) do
    deps(:prod) ++
      [ { :ex_doc, github: "elixir-lang/ex_doc" } ]
  end
end
