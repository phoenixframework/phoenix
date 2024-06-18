defmodule Phoenix.MixProject do
  use Mix.Project

  if Mix.env() != :prod do
    for path <- :code.get_path(),
        Regex.match?(~r/phx_new-[\w\.\-]+\/ebin$/, List.to_string(path)) do
      Code.delete_path(path)
    end
  end

  @version "1.7.14"
  @scm_url "https://github.com/phoenixframework/phoenix"

  # If the elixir requirement is updated, we need to make the installer
  # use at least the minimum requirement used here. Although often the
  # installer is ahead of Phoenix itself.
  @elixir_requirement "~> 1.11"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: package(),
      preferred_cli_env: [docs: :docs],
      consolidate_protocols: Mix.env() != :test,
      xref: [
        exclude: [
          {IEx, :started?, 0},
          Ecto.Type,
          :ranch,
          :cowboy_req,
          Plug.Cowboy.Conn,
          Plug.Cowboy,
          :httpc,
          :public_key
        ]
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Phoenix",
      docs: docs(),
      aliases: aliases(),
      source_url: @scm_url,
      homepage_url: "https://www.phoenixframework.org",
      description: "Peace of mind from prototype to production"
    ]
  end

  defp elixirc_paths(:docs), do: ["lib", "installer/lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_applications(:test), do: [:inets]
  defp extra_applications(_), do: []

  def application do
    [
      mod: {Phoenix, []},
      extra_applications: extra_applications(Mix.env()) ++ [:logger, :eex, :crypto, :public_key],
      env: [
        logger: true,
        stacktrace_depth: nil,
        filter_parameters: ["password"],
        serve_endpoints: false,
        gzippable_exts: ~w(.js .map .css .txt .text .html .json .svg .eot .ttf),
        static_compressors: [Phoenix.Digester.Gzip]
      ]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:plug_crypto, "~> 1.2 or ~> 2.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_template, "~> 1.0"},
      {:websock_adapter, "~> 0.5.3"},

      # TODO drop phoenix_view as an optional dependency in Phoenix v2.0
      {:phoenix_view, "~> 2.0", optional: true},
      # TODO drop castore when we require OTP 25+
      {:castore, ">= 0.0.0"},

      # Optional deps
      {:plug_cowboy, "~> 2.7", optional: true},
      {:jason, "~> 1.0", optional: true},

      # Docs dependencies (some for cross references)
      {:ex_doc, "~> 0.24", only: :docs},
      {:ecto, "~> 3.0", only: :docs},
      {:ecto_sql, "~> 3.10", only: :docs},
      {:gettext, "~> 0.20", only: :docs},
      {:telemetry_poller, "~> 1.0", only: :docs},
      {:telemetry_metrics, "~> 1.0", only: :docs},
      {:makeup_eex, ">= 0.1.1", only: :docs},
      {:makeup_elixir, "~> 0.16", only: :docs},
      {:makeup_diff, "~> 0.1", only: :docs},

      # Test dependencies
      {:phoenix_html, "~> 4.0", only: [:docs, :test]},
      {:phx_new, path: "./installer", only: [:docs, :test]},
      {:mint, "~> 1.4", only: :test},
      {:mint_web_socket, "~> 1.0.0", only: :test},

      # Dev dependencies
      {:esbuild, "~> 0.8", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie", "Jason Stiebs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @scm_url},
      files:
        ~w(assets/js lib priv CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
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
      groups_for_extras: groups_for_extras(),
      groups_for_functions: [
        Reflection: &(&1[:type] == :reflection)
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp extras do
    [
      "guides/introduction/overview.md",
      "guides/introduction/installation.md",
      "guides/introduction/up_and_running.md",
      "guides/introduction/community.md",
      "guides/introduction/packages_glossary.md",
      "guides/directory_structure.md",
      "guides/request_lifecycle.md",
      "guides/plug.md",
      "guides/routing.md",
      "guides/controllers.md",
      "guides/components.md",
      "guides/ecto.md",
      "guides/contexts.md",
      "guides/json_and_apis.md",
      "guides/mix_tasks.md",
      "guides/telemetry.md",
      "guides/asset_management.md",
      "guides/authentication/mix_phx_gen_auth.md",
      "guides/authentication/api_authentication.md",
      "guides/real_time/channels.md",
      "guides/real_time/presence.md",
      "guides/testing/testing.md",
      "guides/testing/testing_contexts.md",
      "guides/testing/testing_controllers.md",
      "guides/testing/testing_channels.md",
      "guides/deployment/deployment.md",
      "guides/deployment/releases.md",
      "guides/deployment/gigalixir.md",
      "guides/deployment/fly.md",
      "guides/deployment/heroku.md",
      "guides/howto/custom_error_pages.md",
      "guides/howto/file_uploads.md",
      "guides/howto/using_ssl.md",
      "guides/howto/writing_a_channels_client.md",
      "guides/cheatsheets/router.cheatmd",
      "CHANGELOG.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Guides: ~r/guides\/[^\/]+\.md/,
      Authentication: ~r/guides\/authentication\/.?/,
      "Real-time": ~r/guides\/real_time\/.?/,
      Testing: ~r/guides\/testing\/.?/,
      Deployment: ~r/guides\/deployment\/.?/,
      Cheatsheets: ~r/guides\/cheatsheets\/.?/,
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
    # Phoenix.Socket
    # Phoenix.Token
    # Phoenix.VerifiedRoutes

    [
      Testing: [
        Phoenix.ChannelTest,
        Phoenix.ConnTest
      ],
      "Adapters and Plugs": [
        Phoenix.CodeReloader,
        Phoenix.Endpoint.Cowboy2Adapter,
        Phoenix.Endpoint.SyncCodeReloadPlug
      ],
      Digester: [
        Phoenix.Digester.Compressor,
        Phoenix.Digester.Gzip
      ],
      Socket: [
        Phoenix.Socket.Broadcast,
        Phoenix.Socket.Message,
        Phoenix.Socket.Reply,
        Phoenix.Socket.Serializer,
        Phoenix.Socket.Transport
      ]
    ]
  end

  defp aliases do
    [
      docs: ["docs", &generate_js_docs/1],
      "assets.build": ["esbuild module", "esbuild cdn", "esbuild cdn_min", "esbuild main"],
      "assets.watch": "esbuild module --watch",
      "archive.build": &raise_on_archive_build/1
    ]
  end

  defp generate_js_docs(_) do
    Mix.Task.run("app.start")
    System.cmd("npm", ["run", "docs"], cd: "assets")
  end

  defp raise_on_archive_build(_) do
    Mix.raise("""
    You are trying to install "phoenix" as an archive, which is not supported. \
    You probably meant to install "phx_new" instead
    """)
  end
end
