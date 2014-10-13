defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix,
     version: "0.5.0",
     elixir: "~> 1.0.1 or ~> 1.1",
     deps: deps,
     package: [
       contributors: ["Chris McCord", "Darko Fabijan", "José Valim"],
       licenses: ["MIT"],
       links: [github: "https://github.com/phoenixframework/phoenix"]
     ],
     description: """
     Elixir Web Framework targeting full-featured, fault tolerant applications
     with realtime functionality
     """]
  end

  def application do
    [mod: {Phoenix, []},
     applications: [:plug, :linguist, :poison, :logger],
     env: [code_reloader: false,
           template_engines: [eex: Phoenix.Template.EExEngine],
           topics: [garbage_collect_after_ms: 60_000..300_000]]]
  end

  def deps do
    [{:cowboy, "~> 1.0", optional: true},
     {:linguist, "~> 0.1.2"},
     {:plug, "~> 0.8.1"},
     {:poison, "~> 1.1"},
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.6", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},
     {:websocket_client, github: "jeremyong/websocket_client", only: :test}]
  end
end
