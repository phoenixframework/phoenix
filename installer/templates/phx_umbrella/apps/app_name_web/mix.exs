defmodule <%= @web_namespace %>.MixProject do
  use Mix.Project

  def project do
    [
      app: :<%= @web_app_name %>,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
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
      mod: {<%= @web_namespace %>.Application, []},
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
      {:phoenix_ecto, "~> 4.4"},<% end %><%= if @html do %>
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.16"},
      {:floki, ">= 0.30.0", only: :test},<% end %><%= if @dashboard do %>
      {:phoenix_live_dashboard, "~> 0.7.2"},<% end %><%= if @assets do %>
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.1.8", runtime: Mix.env() == :dev},<% end %>
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},<%= if @gettext do %>
      {:gettext, "~> 0.20"},<% end %><%= if @app_name != @web_app_name do %>
      {:<%= @app_name %>, in_umbrella: true},<% end %>
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"<%= if @assets do %>, "assets.setup", "assets.build"<% end %>]<%= if @ecto do %>,
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]<% end %><%= if @assets do %>,
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]<% end %>
    ]
  end
end
