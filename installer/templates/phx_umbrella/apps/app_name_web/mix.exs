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
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:floki, ">= 0.30.0", only: :test},<% end %><%= if @dashboard do %>
      {:phoenix_live_dashboard, "~> 0.8.3"},<% end %><%= if @javascript do %>
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},<% end %><%= if @css do %>
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},<% end %>
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},<%= if @gettext do %>
      {:gettext, "~> 0.20"},<% end %><%= if @app_name != @web_app_name do %>
      {:<%= @app_name %>, in_umbrella: true},<% end %>
      {:jason, "~> 1.2"},
      {<%= inspect @web_adapter_app %>, "<%= @web_adapter_vsn %>"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"<%= if @asset_builders != [] do %>, "assets.setup", "assets.build"<% end %>]<%= if @ecto do %>,
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]<% end %><%= if @asset_builders != [] do %>,
      "assets.setup": <%= inspect Enum.map(@asset_builders, &"#{&1}.install --if-missing") %>,
      "assets.build": <%= inspect Enum.map(@asset_builders, &"#{&1} #{@web_app_name}") %>,
      "assets.deploy": [
<%= Enum.map(@asset_builders, &"        \"#{&1} #{@web_app_name} --minify\",\n") ++ ["        \"phx.digest\""] %>
      ]<% end %>
    ]
  end
end
