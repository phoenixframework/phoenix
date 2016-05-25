defmodule Phoenix.New.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_new,
     version: "1.2.0-rc.1",
     elixir: "~> 1.2"]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end
end
