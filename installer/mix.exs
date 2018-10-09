defmodule Phx.New.MixProject do
  use Mix.Project

  @github_path "phoenixframework/phoenix"
  @url "https://github.com/#{@github_path}"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env() == :prod,
      version: "1.4.0-rc.0",
      elixir: "~> 1.5",
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
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Phoenix framework project generator.

      Provides a `mix phx.new` task to bootstrap a new Elixir application
      with Phoenix dependencies.
      """
    ]
  end


  def deps do
    [{:ex_doc, "~> 0.19.1", only: :docs}]
  end

  defp docs do
    [
      source_url_pattern: "https://github.com/#{@github_path}/blob/master/installer/%{path}#L%{line}"
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end
end
