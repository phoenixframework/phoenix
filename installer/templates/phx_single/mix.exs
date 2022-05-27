defmodule <%= @app_module %>.MixProject do
  use Mix.Project

  def project do
    [
      app: :<%= @app_name %>,
      version: "0.1.0",<%= if @in_umbrella do %>
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",<% end %>
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: <%= if @compilers != [] do %>[<%= Enum.join(@compilers, ", ") %>] ++ <% end %>Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {<%= @app_module %>.Application, []},
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
      <%= @phoenix_dep %>,<%= if @ecto do %>
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {<%= inspect @adapter_app %>, ">= 0.0.0"},<% end %><%= if @html do %>
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      # TODO bump to 0.18 on release
      {:phoenix_live_view, github: "phoenixframework/phoenix_live_view", override: true},
      {:floki, ">= 0.30.0", only: :test},<% end %><%= if @dashboard do %>
      {:phoenix_live_dashboard, "~> 0.6"},<% end %><%= if @assets do %>
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},<% end %><%= if @mailer do %>
      {:swoosh, "~> 1.3"},<% end %>
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},<%= if @gettext do %>
      {:gettext, "~> 0.18"},<% end %>
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"<%= if @ecto do %>, "ecto.setup"<% end %>]<%= if @ecto do %>,
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]<% end %><%= if @assets do %>,
      "assets.deploy": ["esbuild default --minify", "phx.digest"]<% end %>
    ]
  end
end
