for path <- :code.get_path(),
    Regex.match?(~r/phx_new\-\d+\.\d+\.\d\/ebin$/, List.to_string(path)) do
  Code.delete_path(path)
end

defmodule Phx.New.MixProject do
  use Mix.Project

  @version "1.6.0-dev"
  @scm_url "https://github.com/phoenixframework/phoenix"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env() == :prod,
      version: @version,
      elixir: "~> 1.11",
      deps: deps(),
      package: [
        maintainers: [
          "Chris McCord",
          "José Valim",
          "Gary Rennie",
          "Jason Stiebs"
        ],
        licenses: ["MIT"],
        links: %{"GitHub" => @scm_url},
        files: ~w(lib templates mix.exs README.md)
      ],
      preferred_cli_env: [docs: :docs],
      source_url: @scm_url,
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
      {:ex_doc, "~> 0.24", only: :docs}
    ]
  end

  defp docs do
    [
      source_url_pattern: "#{@scm_url}/blob/v#{@version}/installer/%{path}#L%{line}"
    ]
  end
end
