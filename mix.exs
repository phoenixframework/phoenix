defmodule Phoenix.Mixfile do
  use Mix.Project

  @version "1.3.4"

  # TODO v1.4: Update to elixir 1.4 + new application inference

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: "~> 1.3",
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
        groups_for_modules: groups_for_modules(),
        extras: extras(),
        groups_for_extras: groups_for_extras()
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
      applications: [:plug, :poison, :logger, :eex, :phoenix_pubsub, :crypto],
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
      {:ex_doc, "~> 0.16", only: :docs},
      {:inch_ex, "~> 0.2", only: :docs},
      {:phoenix_guides, git: "https://github.com/phoenixframework/phoenix_guides.git", compile: false, app: false, only: :docs},

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
      "guides/docs/introduction/overview.md",
      "guides/docs/introduction/installation.md",
      "guides/docs/introduction/learning.md",
      "guides/docs/introduction/community.md",

      "guides/docs/up_and_running.md",
      "guides/docs/adding_pages.md",
      "guides/docs/routing.md",
      "guides/docs/plug.md",
      "guides/docs/endpoint.md",
      "guides/docs/controllers.md",
      "guides/docs/views.md",
      "guides/docs/templates.md",
      "guides/docs/channels.md",
      "guides/docs/presence.md",
      "guides/docs/ecto.md",
      "guides/docs/contexts.md",
      "guides/docs/phoenix_mix_tasks.md",
      "guides/docs/errors.md",

      "guides/docs/testing/testing.md",
      "guides/docs/testing/testing_schemas.md",
      "guides/docs/testing/testing_controllers.md",
      "guides/docs/testing/testing_channels.md",

      "guides/docs/deployment/deployment.md",
      "guides/docs/deployment/heroku.md"
      ]
  end

  defp groups_for_extras do
    [
      "Introduction": ~r/guides\/docs\/introduction\/.?/,
      "Guides": ~r/guides\/docs\/[^\/]+\.md/,
      "Testing": ~r/guides\/docs\/testing\/.?/,
      "Deployment": ~r/guides\/docs\/deployment\/.?/
    ]
  end

  defp groups_for_modules do
    # Ungrouped Modules:
    #
    # Phoenix
    # Phoenix.Channel
    # Phoenix.Controller
    # Phoenix.Naming
    # Phoenix.Param
    # Phoenix.Presence
    # Phoenix.Router
    # Phoenix.Token
    # Phoenix.View

    [
      "Endpoint And Plugs": [
        Phoenix.CodeReloader,
        Phoenix.Endpoint,
        Phoenix.Endpoint.CowboyHandler,
        Phoenix.Endpoint.Handler,
        Phoenix.Logger,
      ],

      "Socket And Transport": [
        Phoenix.Socket,
        Phoenix.Socket.Broadcast,
        Phoenix.Socket.Message,
        Phoenix.Socket.Reply,
        Phoenix.Socket.Transport,
        Phoenix.Transports.LongPoll,
        Phoenix.Transports.Serializer,
        Phoenix.Transports.WebSocket,
      ],

      "Templating": [
        Phoenix.Template,
        Phoenix.Template.EExEngine,
        Phoenix.Template.Engine,
        Phoenix.Template.ExsEngine,
        Phoenix.Template.HTML,
      ],

      "Testing": [
        Phoenix.ChannelTest,
        Phoenix.ConnTest,
      ],
    ]
  end

  defp aliases do
    [
      docs: ["docs", &generate_js_docs/1]
    ]
  end

  def generate_js_docs(_) do
    Mix.Task.run "app.start"
    System.cmd("npm", ["run", "docs"])
  end
end
