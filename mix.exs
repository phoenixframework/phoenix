defmodule Phoenix.Mixfile do
  use Mix.Project

  @version "1.2.3"

  def project do
    [app: :phoenix,
     version: @version,
     elixir: "~> 1.2",
     deps: deps(),
     package: package(),

     # Because we define protocols on the fly to test
     # Phoenix.Param, we need to disable consolidation
     # for the test environment for Elixir v1.2 onward.
     consolidate_protocols: Mix.env != :test,
     xref: [exclude: [Ecto.Type]],

     name: "Phoenix",
     docs: [source_ref: "v#{@version}", main: "Phoenix", logo: "logo.png"],
     source_url: "https://github.com/phoenixframework/phoenix",
     homepage_url: "http://www.phoenixframework.org",
     description: """
     Productive. Reliable. Fast. A productive web framework that
     does not compromise speed and maintainability.
     """]
  end

  def application do
    [mod: {Phoenix, []},
     applications: [:plug, :poison, :logger, :eex],
     env: [stacktrace_depth: nil,
           template_engines: [],
           format_encoders: [],
           generators: [],
           filter_parameters: ["password"],
           serve_endpoints: false,
           gzippable_exts: ~w(.js .css .txt .text .html .json .svg)]]
  end

  defp deps do
    [{:cowboy, "~> 1.0", optional: true},
     {:plug, "~> 1.4 or ~> 1.3.3 or ~> 1.2.4 or ~> 1.1.8 or ~> 1.0.5"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poison, "~> 1.5 or ~> 2.0"},
     {:gettext, "~> 0.8", only: :test},

     # Docs dependencies
     {:ex_doc, "~> 0.12", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},

     # Test dependencies
     {:phoenix_html, "~> 2.6", only: :test},
     {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test}]
  end

  defp package do
    [maintainers: ["Chris McCord", "José Valim", "Lance Halvorsen",
                    "Jason Stiebs", "Eric Meadows-Jönsson", "Sonny Scroggin"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/phoenixframework/phoenix"},
     files: ~w(lib priv web) ++
            ~w(brunch-config.js CHANGELOG.md LICENSE.md mix.exs package.json README.md)]
  end
end
