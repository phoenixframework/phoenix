defmodule Phoenix.MixProject do
  use Mix.Project

  @version "1.5.14"

  # If the elixir requirement is updated, we need to make the installer
  # use at least the minimum requirement used here. Although often the
  # installer is ahead of Phoenix itself.
  @elixir_requirement "~> 1.7"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: package(),
      lockfile: lockfile(),
      preferred_cli_env: [docs: :docs],
      consolidate_protocols: Mix.env() != :test,
      xref: [
        exclude: [
          {IEx, :started?, 0},
          Ecto.Type,
          :ranch,
          :cowboy_req,
          Plug.Adapters.Cowboy.Conn,
          Plug.Cowboy.Conn,
          Plug.Cowboy
        ]
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Phoenix",
      docs: docs(),
      aliases: aliases(),
      source_url: "https://github.com/phoenixframework/phoenix",
      homepage_url: "https://www.phoenixframework.org",
      description: """
      Productive. Reliable. Fast. A productive web framework that
      does not compromise speed or maintainability.
      """
    ]
  end

  defp elixirc_paths(:docs), do: ["lib", "installer/lib"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Phoenix, []},
      extra_applications: [:logger, :eex, :crypto, :public_key],
      env: [
        logger: true,
        stacktrace_depth: nil,
        template_engines: [],
        format_encoders: [],
        filter_parameters: ["password"],
        serve_endpoints: false,
        gzippable_exts: ~w(.js .css .txt .text .html .json .svg .eot .ttf),
        trim_on_html_eex_engine: true
      ]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.10"},
      {:plug_crypto, "~> 1.1.2 or ~> 1.2"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},

      # Optional deps
      {:plug_cowboy, "~> 1.0 or ~> 2.2", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:phoenix_html, "~> 2.13 or ~> 3.0", optional: true},

      # Docs dependencies
      {:ex_doc, "~> 0.22", only: :docs},
      {:inch_ex, "~> 0.2", only: :docs},

      # Test dependencies (some also include :docs for cross references)
      {:gettext, "~> 0.15.0", only: [:docs, :test]},
      {:telemetry_poller, "~> 0.4", only: [:docs, :test]},
      {:telemetry_metrics, "~> 0.4", only: [:docs, :test]},
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
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie", "Jason Stiebs"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/phoenixframework/phoenix"},
      files: ~w(assets/js lib priv CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
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
      "guides/introduction/up_and_running.md",
      "guides/introduction/community.md",

      "guides/directory_structure.md",
      "guides/request_lifecycle.md",
      "guides/plug.md",
      "guides/routing.md",
      "guides/controllers.md",
      "guides/views.md",
      "guides/ecto.md",
      "guides/contexts.md",
      "guides/mix_tasks.md",
      "guides/telemetry.md",

      "guides/realtime/channels.md",
      "guides/realtime/presence.md",

      "guides/testing/testing.md",
      "guides/testing/testing_contexts.md",
      "guides/testing/testing_controllers.md",
      "guides/testing/testing_channels.md",

      "guides/deployment/deployment.md",
      "guides/deployment/releases.md",
      "guides/deployment/gigalixir.md",
      "guides/deployment/heroku.md",

      "guides/howto/custom_error_pages.md",
      "guides/howto/using_ssl.md",
    ]
  end

  defp groups_for_extras do
    [
      "Introduction": ~r/guides\/introduction\/.?/,
      "Guides": ~r/guides\/[^\/]+\.md/,
      "Real-time components": ~r/guides\/realtime\/.?/,
      "Testing": ~r/guides\/testing\/.?/,
      "Deployment": ~r/guides\/deployment\/.?/,
      "How-to's": ~r/guides\/howto\/.?/
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
    # Phoenix.Logger
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
        Phoenix.Endpoint.Cowboy2Adapter
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
