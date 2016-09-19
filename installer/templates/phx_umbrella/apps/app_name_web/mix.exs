defmodule <%= web_namespace %>.Mixfile do
  use Mix.Project

  def project do
    [app: :<%= web_app_name %>,
     version: "0.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {<%= web_namespace %>, []},
     applications: [:phoenix<%= if html do %>, :phoenix_html<% end %>, :cowboy, :logger, :gettext,
                    <%= if ecto do %>:phoenix_ecto,<% end %> :<%= app_name %>]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [<%= phoenix_dep %>,
     {:phoenix_pubsub, "~> 1.0"},<%= if ecto do %>
     {:phoenix_ecto, "~> 3.1-rc.0"},<% end %><%= if html do %>
     {:phoenix_html, "~> 2.6"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},<% end %>
     {:gettext, "~> 0.11"},
     {:<%= app_name %>, in_umbrella: true},
     {:cowboy, "~> 1.0"}]
  end
end
