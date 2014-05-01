Code.ensure_loaded?(Hex) and Hex.start

defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [
      app: :phoenix,
      version: "0.2.0",
      elixir: "~> 0.13.0",
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
      applications: [:cowboy, :plug, :ex_conf]
    ]
  end

  defp deps(:prod) do
    [
      {:cowboy, github: "extend/cowboy"},
      {:plug, "0.4.2"},
      {:inflex, github: "nurugger07/inflex"},
      {:ex_conf, "0.1.1"},
      {:jazz, github: "meh/jazz"}
    ]
  end

  defp deps(_) do
    deps(:prod) ++
      [ { :ex_doc, github: "elixir-lang/ex_doc" } ]
  end
end
