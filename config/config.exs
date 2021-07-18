import Config

config :logger, :console, colors: [enabled: false]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :json_library, Jason

config :phoenix, :trim_on_html_eex_engine, false

config :esbuild,
  version: "0.12.15",
  default: [
    args: ~w(./js/phoenix --bundle --sourcemap --format=esm --outfile=../priv/static/phoenix.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
