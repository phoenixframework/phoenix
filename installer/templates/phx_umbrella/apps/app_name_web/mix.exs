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
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: <%= if @gettext do %>[:gettext] ++ <% end %>Mix.compilers(),
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
      {:phoenix_ecto, "~> 4.1"},<% end %><%= if @html do %>
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.15.7"},
      {:floki, ">= 0.30.0", only: :test},<% end %><%= if @dashboard do %>
      {:phoenix_live_dashboard, "~> 0.4"},<% end %><%= if @assets do %>
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},<% end %>
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},<%= if @gettext do %>
      {:gettext, "~> 0.11"},<% end %><%= if @app_name != @web_app_name do %>
      {:<%= @app_name %>, in_umbrella: true},<% end %>
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]<%= if @ecto do %>,
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]<% end %><%= if @assets do %>,
      "assets.deploy": ["esbuild default --minify", "phx.digest"]<% end %>
    ]
  end
end
