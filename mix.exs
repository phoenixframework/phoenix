defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix,
     version: "0.7.2",
     elixir: "~> 1.0.2 or ~> 1.1-dev",
     deps: deps,
     package: package,
     docs: &docs/0,
     name: "Phoenix",
     source_url: "https://github.com/phoenixframework/phoenix",
     homepage_url: "http://www.phoenixframework.org",
     description: """
     Elixir Web Framework targeting full-featured, fault tolerant applications
     with realtime functionality
     """]
  end

  def application do
    [mod: {Phoenix, []},
     applications: [:plug, :poison, :logger],
     env: [code_reloader: false,
           template_engines: [],
           format_encoders: [],
           pubsub: [garbage_collect_after_ms: 60_000..300_000],
           filter_parameters: ["password"]]]
  end

  defp deps do
    [{:cowboy, "~> 1.0", optional: true},
     {:plug, "~> 0.9.0"},
     {:poison, "~> 1.2"},
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.6", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},
     {:websocket_client, github: "jeremyong/websocket_client", only: :test}]
  end

  defp package do
    [contributors: ["Chris McCord", "Darko Fabijan", "José Valim"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/phoenixframework/phoenix"}]
  end

  defp docs do
    {ref, 0} = System.cmd("git", ["rev-parse", "--verify", "--quiet", "HEAD"])
    [source_ref: ref,
     main: "overview",
     readme: true]
  end
end
