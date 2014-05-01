defmodule <%= application_module %>.Mixfile do
  use Mix.Project

  def project do
    [ app: :<%= application_name %>,
      version: "0.0.1",
      elixir: "~> 0.13.0",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [mod: { <%= application_module %>, [] }]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  defp deps do
    [
      {:phoenix, "0.2.0"},
      {:cowboy, github: "extend/cowboy", ref: "05024529679d1d0203b8dcd6e2932cc2a526d370"},
      {:jazz, github: "meh/jazz", ref: "24b6eedb87aff6e97c5116f94d48476acb46dffe"}
    ]
  end
end
