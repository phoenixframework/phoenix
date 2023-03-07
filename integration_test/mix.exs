for path <- :code.get_path(),
    Regex.match?(~r/phx_new-[\w\.\-]+\/ebin$/, List.to_string(path)) do
  Code.delete_path(path)
end

defmodule Phoenix.Integration.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_integration,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  # IMPORTANT: Dependencies are initially compiled with `MIX_ENV=test` and then
  # copied to `_build/dev` to save time. Any dependencies with `only: :dev` set
  # will not be copied.
  defp deps do
    [
      {:phx_new, path: "../installer"},
      {:phoenix, path: "..", override: true},
      {:phoenix_ecto, "~> 4.4"},
      {:esbuild, "~> 0.5", runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:myxql, ">= 0.0.0"},
      {:tds, ">= 0.0.0"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_view, "~> 0.18.16"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:swoosh, "~> 1.3"},
      {:plug_cowboy, "~> 2.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:argon2_elixir, "~> 3.0"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:tailwind, "~> 0.1"},
      {:finch, "~> 0.13"}
    ]
  end
end
