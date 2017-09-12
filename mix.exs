defmodule Phoenix.Mixfile do
  use Mix.Project

  @version "1.4.0-dev"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: "~> 1.4",
      deps: deps(),
      package: package(),
      preferred_cli_env: [docs: :docs],

      # Because we define protocols on the fly to test
      # Phoenix.Param, we need to disable consolidation
      # for the test environment for Elixir v1.2 onward.
      consolidate_protocols: Mix.env != :test,
      xref: [exclude: [Ecto.Type]],

      name: "Phoenix",
      docs: [
        source_ref: "v#{@version}",
        main: "overview",
        logo: "logo.png",
        extra_section: "GUIDES",
        assets: "guides/docs/assets",
        formatters: ["html", "epub"],
        extras: extras()
      ],
      aliases: aliases(),
      source_url: "https://github.com/phoenixframework/phoenix",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Productive. Reliable. Fast. A productive web framework that
      does not compromise speed and maintainability.
      """
    ]
  end

  def application do
    [
      mod: {Phoenix, []},
      extra_applications: [:logger, :eex, :crypto],
      env: [
        stacktrace_depth: nil,
        template_engines: [],
        format_encoders: [],
        filter_parameters: ["password"],
        serve_endpoints: false,
        gzippable_exts: ~w(.js .css .txt .text .html .json .svg)
      ]
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 1.0", optional: true},
      {:plug, "~> 1.3.3 or ~> 1.4"},
      {:phoenix_pubsub, "~> 1.0"},
      {:poison, "~> 2.2 or ~> 3.0"},
      {:gettext, "~> 0.8", only: :test},

      # Docs dependencies
      {:ex_doc, "~> 0.16.4", only: :docs},
      {:inch_ex, "~> 0.2", only: :docs},

      # Test dependencies
      {:phoenix_html, "~> 2.10", only: :test},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test}
    ]
  end

  defp package do
    [
      maintainers: [
        "Chris McCord", "José Valim", "Lance Halvorsen", "Gary Rennie",
        "Jason Stiebs", "Eric Meadows-Jönsson", "Sonny Scroggin"
      ],
      licenses: ["MIT"],
      links: %{github: "https://github.com/phoenixframework/phoenix"},
      files: ~w(assets lib priv) ++
        ~w(brunch-config.js CHANGELOG.md LICENSE.md mix.exs package.json README.md)
    ]
  end

  defp extras do
    [
      "introduction/overview.md": [group: "Introduction"],
      "introduction/installation.md": [group: "Introduction"],
      "introduction/learning.md": [group: "Introduction"],
      "introduction/community.md": [group: "Introduction"],

      "up_and_running.md": [group: "Guides"],
      "adding_pages.md": [group: "Guides"],
      "routing.md": [group: "Guides"],
      "plug.md": [group: "Guides"],
      "endpoint.md": [group: "Guides"],
      "controllers.md": [group: "Guides"],
      "views.md": [group: "Guides"],
      "templates.md": [group: "Guides"],
      "channels.md": [group: "Guides"],
      "ecto.md": [group: "Guides"],
      "contexts.md": [group: "Guides"],
      "phoenix_mix_tasks.md": [group: "Guides"],
      "errors.md": [group: "Guides"],

      "testing/testing.md": [group: "Testing"],
      "testing/testing_schemas.md": [group: "Testing"],
      "testing/testing_controllers.md": [group: "Testing"],
      "testing/testing_channels.md": [group: "Testing"],

      "deployment/deployment.md": [group: "Deployment"],
      "deployment/heroku.md": [group: "Deployment"]
    ]
    |> Enum.map(fn {file, opts} -> {:"guides/docs/#{file}", opts} end)
  end

  defp aliases do
    [
      "docs": ["docs", &generate_js_docs/1]
    ]
  end

  def generate_js_docs(_) do
    Mix.Task.run "app.start"
    System.cmd("npm", ["run", "docs"])
  end
end
