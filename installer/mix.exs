defmodule Phx.New.Mixfile do
  use Mix.Project

  def project do
    [app: :phx_new,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     version: "1.3.0-dev",
     elixir: "~> 1.4"]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end
end
