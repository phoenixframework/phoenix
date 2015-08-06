defmodule Phoenix.New.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_new,
     version: "0.16.1",
     elixir: "~> 1.0-dev"]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end
end
