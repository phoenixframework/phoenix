defmodule Phoenix.Mixfile do
  use Mix.Project

  @version "0.14.0-dev"

  def project do
    [app: :phoenix,
     version: @version,
     elixir: "~> 1.0.2 or ~> 1.1-dev",
     deps: deps,
     package: package,
     docs: [source_ref: "v#{@version}", main: "overview"],
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
     {:plug, ">= 0.12.2 and < 2.0.0"},
     {:poison, "~> 1.3"},
     {:redo, github: "heroku/redo", optional: true},
     {:poolboy, "~> 1.5.1 or ~> 1.6", optional: true},

     # Docs dependencies
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.7.1", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},

     # Test dependencies
     {:phoenix_html, "~> 1.1", only: :test},
     {:websocket_client, github: "jeremyong/websocket_client", only: :test}]
  end

  defp package do
    [contributors: ["Chris McCord", "Darko Fabijan", "José Valim"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/phoenixframework/phoenix"}]
  end
end
