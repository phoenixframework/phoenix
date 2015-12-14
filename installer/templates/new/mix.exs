defmodule <%= application_module %>.Mixfile do
  use Mix.Project

  def project do
    [app: :<%= application_name %>,
     version: "0.0.1",<%= if in_umbrella do %>
     deps_path: "../../deps",
     lockfile: "../../mix.lock",<% end %>
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,<%= if ecto do %>
     aliases: aliases,<% end %>
     deps: deps]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {<%= application_module %>, []},
     applications: [:phoenix<%= if html do %>, :phoenix_html<% end %>, :cowboy, :logger, :gettext<%= if ecto do %>,
                    :phoenix_ecto, <%= inspect adapter_app %><% end %>]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [<%= phoenix_dep %>,<%= if ecto do %>
     {:phoenix_ecto, "~> 2.0"},
     {<%= inspect adapter_app %>, ">= 0.0.0"},<% end %><%= if html do %>
     {:phoenix_html, "~> 2.1"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},<% end %>
     {:gettext, "~> 0.8"},
     {:cowboy, "~> 1.0"}]
  end<%= if ecto do %>

  # Aliases are shortcut or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end<% end %>
end
