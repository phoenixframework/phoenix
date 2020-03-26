defmodule <%= app_module %>.MixProject do
  use Mix.Project

  def project do
    [
      app: :<%= app_name %>,
      version: "0.1.0",<%= if in_umbrella do %>
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",<% end %>
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix<%= if gettext do %>, :gettext<% end %>] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,<%= if ecto do %>
      aliases: aliases(),<% end %>
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {<%= app_module %>.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      <%= phoenix_dep %>,<%= if ecto do %>
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {<%= inspect adapter_app %>, ">= 0.0.0"},<% end %><%= if html do %><%= if live do %>
      {:phoenix_live_view, "~> 0.10.0"},
      {:floki, ">= 0.0.0", only: :test},<% end %><%= if dashboard do %>
      {:phoenix_live_dashboard, github: "phoenixframework/phoenix_live_dashboard"},<% end %>
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},<% end %>
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},<%= if gettext do %>
      {:gettext, "~> 0.11"},<% end %>
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end<%= if ecto do %>

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end<% end %>
end
