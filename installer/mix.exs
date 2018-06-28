defmodule Phx.New.MixProject do
  use Mix.Project

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env == :prod,
      version: "1.4.0-dev",
      elixir: "~> 1.5"
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end
end
