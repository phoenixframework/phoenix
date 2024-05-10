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
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {<%= inspect @adapter_app %>, ">= 0.0.0"},<% end %><%= if @html do %>
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      # TODO bump on release to {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_view, "~> 1.0.0-rc.0", override: true},
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
       depth: 1},<% end %><%= if @mailer do %>
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},<% end %>
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},<%= if @gettext do %>
      {:gettext, "~> 0.20"},<% end %>
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {<%= inspect @web_adapter_app %>, "<%= @web_adapter_vsn %>"}
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
      setup: ["deps.get"<%= if @ecto do %>, "ecto.setup"<% end %><%= if @asset_builders != [] do %>, "assets.setup", "assets.build"<% end %>]<%= if @ecto do %>,
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]<% end %><%= if @asset_builders != [] do %>,
      "assets.setup": <%= inspect Enum.map(@asset_builders, &"#{&1}.install --if-missing") %>,
      "assets.build": <%= inspect Enum.map(@asset_builders, &"#{&1} #{@app_name}") %>,
      "assets.deploy": [
<%= Enum.map(@asset_builders, &"        \"#{&1} #{@app_name} --minify\",\n") ++ ["        \"phx.digest\""] %>
      ]<% end %>
    ]
  end
end
