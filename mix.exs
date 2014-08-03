defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [
      app: :phoenix,
      version: "0.3.1",
      elixir: "~> 0.15.0",
      deps: deps(Mix.env),
      package: [
        contributors: ["Chris McCord", "Darko Fabijan"],
        licenses: ["MIT"],
        links: [github: "https://github.com/phoenixframework/phoenix"]
      ],
      description: """
      Elixir Web Framework targeting full-featured, fault tolerant applications
      with realtime functionality
      """
    ]
  end

  def application do
    [
      mod: { Phoenix, [] },
      applications: [:cowboy, :plug]
    ]
  end

  defp deps(:prod) do
    [
      {:cowboy, "~> 1.0.0", optional: true},
      {:plug, "0.5.3"},
      {:inflex, "0.2.4"},
      {:linguist, "~> 0.1.0"},
      {:jazz, "0.1.2"},
    ]
  end

  defp deps(_) do
    deps(:prod) ++
      [ {:ex_doc, github: "elixir-lang/ex_doc", only: [:docs]} ]
  end
end
