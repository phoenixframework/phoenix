defmodule Phx.New.Mixfile do
  use Mix.Project

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env == :prod,
      version: "1.3.0-rc.2",
      elixir: "~> 1.3 or ~> 1.4"
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end
end
