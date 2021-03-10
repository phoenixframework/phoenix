for path <- :code.get_path(),
    Regex.match?(~r/phx_new\-\d+\.\d+\.\d\/ebin$/, List.to_string(path)) do
  Code.delete_path(path)
end

defmodule Phx.New.MixProject do
  use Mix.Project

  @version "1.6.0-dev"
  @github_default_branch "master"
  @github_path "phoenixframework/phoenix"
  @url "https://github.com/#{@github_path}"

  def project do
    [
      app: :phx_new,
      start_permanent: Mix.env() == :prod,
      version: @version,
      revision: revision(),
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
        links: %{"GitHub" => @url},
        files: ~w(lib templates mix.exs README.md)
      ],
      source_url: @url,
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
      {:ex_doc, "~> 0.23", only: :docs}
    ]
  end

  defp docs do
    [
      source_url_pattern:
        "https://github.com/#{@github_path}/blob/#{source_ref()}/installer/%{path}#L%{line}"
    ]
  end

  # NOTE: If this function gets updated, update ../mix.exs, and viceversa.
  defp source_ref() do
    cond do
      revision() != "" ->
        revision()

      %{pre: "dev"} = Version.parse!(@version) ->
        @github_default_branch

      true ->
        "v" <> @version
    end
  end

  # Originally taken from the Elixir Programming Language.
  # https://github.com/elixir-lang/elixir/blob/6db7b54/lib/elixir/lib/system.ex#L130}
  # NOTE: If this function gets updated, update ../mix.exs, and viceversa.
  #
  # Tries to run "git rev-parse --short=7 HEAD". In the case of success returns
  # the short revision hash. If that fails, returns an empty string.
  defmacrop get_revision do
    null =
      case :os.type() do
        {:win32, _} -> 'NUL'
        _ -> '/dev/null'
      end

    ('git rev-parse --short=7 HEAD 2> ' ++ null)
    |> :os.cmd()
    |> :re.replace("^[\s\r\n\t]+|[\s\r\n\t]+$", "", [:global, return: :binary])
  end

  defp revision, do: get_revision()
end
