defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix,
     version: "0.7.0-dev",
     elixir: "~> 1.0.2 or ~> 1.1",
     deps: deps,
     package: [
       contributors: ["Chris McCord", "Darko Fabijan", "José Valim"],
       licenses: ["MIT"],
       links: %{github: "https://github.com/phoenixframework/phoenix"}
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
           template_engines: [],
           format_encoders: [],
           pubsub: [garbage_collect_after_ms: 60_000..300_000],
           filter_parameters: ["password"]]]
  end

  def deps do
    [{:cowboy, "~> 1.0", optional: true},
     {:linguist, "~> 0.1.4"},
     {:plug, "~> 0.8.4"},
     {:poison, "~> 1.2"},
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.6", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},
     {:websocket_client, github: "jeremyong/websocket_client", only: :test}]
  end
end
