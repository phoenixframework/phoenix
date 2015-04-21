defmodule Phoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix,
     version: "0.12.0-dev",
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
     applications: [:plug, :poison, :logger, :eex],
     env: [template_engines: [],
           format_encoders: [],
           filter_parameters: ["password"],
           serve_endpoints: false]]
  end

  defp deps do
    [{:cowboy, "~> 1.0", optional: true},
     {:plug, "~> 0.12.1"},
     {:poison, "~> 1.3"},
     {:redo, github: "heroku/redo", optional: true},
     {:poolboy, "~> 1.5.1", optional: true},

     # Docs dependencies
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.7.1", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},

     # Test dependencies
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
     main: "overview"]
  end
end
