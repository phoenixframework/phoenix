defmodule Phoenix.MixProject do
  use Mix.Project

  @version "1.4.0"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: "~> 1.4",
      deps: deps(),
      package: package(),
      lockfile: lockfile(),
      preferred_cli_env: [docs: :docs],
      consolidate_protocols: Mix.env != :test,
      xref: [exclude: [Ecto.Type, :ranch, {:cowboy_req, :compact, 1}, Plug.Adapters.Cowboy.Conn, Plug.Cowboy.Conn]],
      elixirc_paths: elixirc_paths(Mix.env),
      name: "Phoenix",
      docs: docs(),
      aliases: aliases(),
      source_url: "https://github.com/phoenixframework/phoenix",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Productive. Reliable. Fast. A productive web framework that
      does not compromise speed and maintainability.
      """
    ]
  end

  defp elixirc_paths(:docs), do: ["lib", "installer/lib"]
  defp elixirc_paths(_), do: ["lib"]

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
        gzippable_exts: ~w(.js .css .txt .text .html .json .svg .eot .ttf)
      ]
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 1.0 or ~> 2.0", optional: true},
      {:plug, "~> 1.7"},
      {:phoenix_pubsub, "~> 1.1"},
      {:jason, "~> 1.0", optional: true},

      # Docs dependencies
      {:ex_doc, "~> 0.19.1", only: :docs},
      {:inch_ex, "~> 0.2", only: :docs},

      # Test dependencies
      {:gettext, "~> 0.15.0", only: :test},
      {:phoenix_html, "~> 2.11", only: :test},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test}
    ]
  end

  defp lockfile() do
    case System.get_env("COWBOY_VERSION") do
      "1" <> _ -> "mix-cowboy1.lock"
      _ -> "mix.lock"
    end
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
        ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      logo: "logo.png",
      extra_section: "GUIDES",
      assets: "guides/assets",
      formatters: ["html", "epub"],
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras do
    [
      "guides/introduction/overview.md",
      "guides/introduction/installation.md",
      "guides/introduction/learning.md",
      "guides/introduction/community.md",

      "guides/up_and_running.md",
      "guides/adding_pages.md",
      "guides/routing.md",
      "guides/plug.md",
      "guides/endpoint.md",
      "guides/controllers.md",
      "guides/views.md",
      "guides/templates.md",
      "guides/channels.md",
      "guides/presence.md",
      "guides/ecto.md",
      "guides/contexts.md",
      "guides/phoenix_mix_tasks.md",
      "guides/errors.md",

      "guides/testing/testing.md",
      "guides/testing/testing_schemas.md",
      "guides/testing/testing_controllers.md",
      "guides/testing/testing_channels.md",

      "guides/deployment/deployment.md",
      "guides/deployment/heroku.md"
      ]
  end

  defp groups_for_extras do
    [
      "Introduction": ~r/guides\/introduction\/.?/,
      "Guides": ~r/guides\/[^\/]+\.md/,
      "Testing": ~r/guides\/testing\/.?/,
      "Deployment": ~r/guides\/deployment\/.?/
    ]
  end

  defp groups_for_modules do
    # Ungrouped Modules:
    #
    # Phoenix
    # Phoenix.Channel
    # Phoenix.Controller
    # Phoenix.Endpoint
    # Phoenix.Naming
    # Phoenix.Param
    # Phoenix.Presence
    # Phoenix.Router
    # Phoenix.Token
    # Phoenix.View

    [
      "Testing": [
        Phoenix.ChannelTest,
        Phoenix.ConnTest,
      ],

      "Adapters and Plugs": [
        Phoenix.CodeReloader,
        Phoenix.Endpoint.CowboyAdapter,
        Phoenix.Endpoint.Cowboy2Adapter,
        Phoenix.Logger,
      ],

      "Socket and Transport": [
        Phoenix.Socket,
        Phoenix.Socket.Broadcast,
        Phoenix.Socket.Message,
        Phoenix.Socket.Reply,
        Phoenix.Socket.Serializer,
        Phoenix.Socket.Transport
      ],

      "Templating": [
        Phoenix.Template,
        Phoenix.Template.EExEngine,
        Phoenix.Template.Engine,
        Phoenix.Template.ExsEngine,
        Phoenix.Template.HTML,
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
    System.cmd("npm", ["run", "docs"], cd: "assets")
  end
end
