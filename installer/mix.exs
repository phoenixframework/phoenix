defmodule Phx.New.MixProject do
  use Mix.Project

  @version "1.5.0"
  @github_path "phoenixframework/phoenix"
  @url "https://github.com/#{@github_path}"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env() == :prod,
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      package: [
        maintainers: [
          "Chris McCord",
          "José Valim",
          "Gary Rennie",
          "Jason Stiebs"
        ],
        licenses: ["MIT"],
        links: %{github: @url},
        files: ~w(lib templates mix.exs README.md)
      ],
      source_url: @url,
      docs: docs(),
      homepage_url: "https://www.phoenixframework.org",
      description: """
      Phoenix framework project generator.

      Provides a `mix phx.new` task to bootstrap a new Elixir application
      with Phoenix dependencies.
      """
    ]
  end

  def application do
    [
      extra_applications: [:eex, :crypto]
    ]
  end

  def deps do
    [
      {:ex_doc, "~> 0.19.1", only: :docs}
    ]
  end

  defp docs do
    [
      source_url_pattern:
        "https://github.com/#{@github_path}/blob/v#{@version}/installer/%{path}#L%{line}"
    ]
  end
end
