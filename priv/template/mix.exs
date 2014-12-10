defmodule <%= application_module %>.Mixfile do
  use Mix.Project

  def project do
    [app: :<%= application_name %>,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {<%= application_module %>, []},
     applications: [:phoenix, :cowboy, :logger]]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:plug, github: "elixir-lang/plug", ref: "7040c89cb4cf1f1c6afdee379e5982a07d77a6c3"},
     {:phoenix, "~> 0.7.1"},
     {:cowboy, "~> 1.0"}]
  end
end
