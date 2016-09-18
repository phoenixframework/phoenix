defmodule <%= app_module %>.Mixfile do
  use Mix.Project

  def project do
    [app: :<%= app_name %>,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger<%= if ecto do %>, :<%= adapter_app %>, :ecto<% end %>],
     mod: {<%= app_module %>, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [<%= if ecto do %>{:<%= adapter_app %>, ">= 0.0.0"},
     {:ecto, "~> 2.0.0-rc"}<% end %>]
  end

  # Aliases are shortcuts or tasks specific to the current project.<%= if ecto do %>
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup<% end %>
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [<%= if ecto do %>"ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.create --quiet", "ecto.migrate", "test"]<% end %>]
  end
end
