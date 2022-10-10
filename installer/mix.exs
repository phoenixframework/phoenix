defmodule Phx.New.Mixfile do
  use Mix.Project

  @scm_url "https://github.com/phoenixframework/phoenix"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env == :prod,
      version: "1.3.5",
      elixir: "~> 1.3 or ~> 1.4",
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
      source_url: @scm_url,
      homepage_url: "https://www.phoenixframework.org",
      description: """
      Phoenix framework project generator.
      Provides a `mix phx.new` task to bootstrap a new Elixir application
      with Phoenix dependencies.
      """
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end
end
