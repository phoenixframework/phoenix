defmodule <%= application_module %>.Mixfile do
  use Mix.Project

  def project do
    [app: :<%= application_name %>,
     version: "0.0.1",<%= if in_umbrella do %>
     deps_path: "../../deps",
     lockfile: "../../mix.lock",<% end %>
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {<%= application_module %>, []},
     applications: [:phoenix, :cowboy, :logger<%= if ecto do %>,
                    :phoenix_ecto, :postgrex<% end %>]]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [<%= phoenix_dep %>,<%= if ecto do %>
     {:phoenix_ecto, "~> 0.3"},
     {:postgrex, ">= 0.0.0"},<% end %>
     {:phoenix_live_reload, "~> 0.3"},
     {:cowboy, "~> 1.0"}]
  end
end
