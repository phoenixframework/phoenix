defmodule Phoenix.Mixfile do
  use Mix.Project

  @version "1.3.0-dev"

  def project do
    [app: :phoenix,
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
     docs: [source_ref: "v#{@version}",
            main: "overview",
            logo: "logo.png",
            extra_section: "GUIDES",
            assets: "deps/phoenix_guides/images",
            extras: extras()],
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
     {:plug, "~> 1.2.1 or ~> 1.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poison, "~> 2.2 or ~> 3.0"},
     {:gettext, "~> 0.8", only: :test},

     # Docs dependencies
     {:ex_doc, "~> 0.14", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},
     {:phoenix_guides, git: "https://github.com/phoenixframework/phoenix_guides.git", compile: false, app: false, only: :docs},

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

  defp extras do
    [
      "deps/phoenix_guides/docs/introduction/overview.md": [group: "Introduction"],
      "deps/phoenix_guides/docs/introduction/installation.md": [group: "Introduction"],
      "deps/phoenix_guides/docs/introduction/learning.md": [group: "Introduction"],
      "deps/phoenix_guides/docs/introduction/community.md": [group: "Introduction"],

      "deps/phoenix_guides/docs/up_and_running.md": [group: "Guides"],
      "deps/phoenix_guides/docs/adding_pages.md": [group: "Guides"],
      "deps/phoenix_guides/docs/routing.md": [group: "Guides"],
      "deps/phoenix_guides/docs/plug.md": [group: "Guides"],
      "deps/phoenix_guides/docs/controllers.md": [group: "Guides"],
      "deps/phoenix_guides/docs/views.md": [group: "Guides"],
      "deps/phoenix_guides/docs/templates.md": [group: "Guides"],
      "deps/phoenix_guides/docs/channels.md": [group: "Guides"],
      "deps/phoenix_guides/docs/ecto_models.md": [group: "Guides"],

      "deps/phoenix_guides/docs/testing/testing.md": [group: "Testing"],
      "deps/phoenix_guides/docs/testing/testing_models.md": [group: "Testing"],
      "deps/phoenix_guides/docs/testing/testing_controllers.md": [group: "Testing"],
      "deps/phoenix_guides/docs/testing/testing_views.md": [group: "Testing"],
      "deps/phoenix_guides/docs/testing/testing_channels.md": [group: "Testing"],

      "deps/phoenix_guides/docs/deployment/deployment.md": [group: "Deployment"],
      "deps/phoenix_guides/docs/deployment/heroku.md": [group: "Deployment"],
      "deps/phoenix_guides/docs/deployment/exrm_releases.md": [group: "Deployment"],

      "deps/phoenix_guides/docs/bonus_guides/upgrading_phoenix.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/custom_primary_key.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/using_mysql.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/static_assets.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/file_uploads.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/sending_email_with_mailgun.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/sending_email_with_smtp.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/sessions.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/custom_errors.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/using_ssl.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/phoenix_behind_proxy.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/config.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/learning_elixir.md": [group: "Bonus Guides"],
      "deps/phoenix_guides/docs/bonus_guides/seeding_data.md": [group: "Bonus Guides"],
    ]
  end
end
