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
      elixir: "~> 1.15",
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
      {:phoenix_ecto, "~> 4.5"},
      {:esbuild, "~> 0.10", runtime: false},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:myxql, ">= 0.0.0"},
      {:tds, ">= 0.0.0"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:dns_cluster, "~> 0.2.0"},
      {:lazy_html, ">= 0.1.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:swoosh, "~> 1.16"},
      {:bandit, "~> 1.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:argon2_elixir, "~> 4.0"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:tailwind, "~> 0.3"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:req, "~> 0.5"}
    ]
  end
end
