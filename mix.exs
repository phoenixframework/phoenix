defmodule Phoenix.MixProject do
  use Mix.Project

  if Mix.env() != :prod do
    for path <- :code.get_path(),
        Regex.match?(~r/phx_new\-\d+\.\d+\.\d.*\/ebin$/, List.to_string(path)) do
      Code.delete_path(path)
    end
  end

  @version "1.0.0"
  @elixir_requirement "~> 1.9"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Phoenix Templates",
      description: """
      Templates adjusted for Kintu.Games project.
      """
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
    ]
  end

  defp package do
    [
      maintainers: ["Roman Berdichevskii"],
      licenses: ["MIT"],
      files:
        ~w(lib priv LICENSE.md mix.exs README.md .formatter.exs)
    ]
  end
end
