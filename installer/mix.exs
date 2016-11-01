defmodule Phoenix.New.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_new,
     version: "1.2.0",
     elixir: "~> 1.3"]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end
end
