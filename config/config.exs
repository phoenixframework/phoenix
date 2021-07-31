import Config

config :logger, :console, colors: [enabled: false]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :json_library, Jason

config :phoenix, :trim_on_html_eex_engine, false

esbuild_base =  [
  cd: Path.expand("../assets", __DIR__),
  env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
]

config :esbuild,
  version: "0.12.15",
  module: esbuild_base ++ [args: ~w(./js/phoenix --bundle --format=esm --sourcemap --outfile=../priv/static/phoenix.esm.js)],
  cdn: esbuild_base ++ [args: ~w(./js/phoenix --bundle --target=es2016 --format=iife --global-name=Phoenix --outfile=../priv/static/phoenix.js)],
  cdn_min: esbuild_base ++ [args: ~w(./js/phoenix --bundle --target=es2016 --format=iife --global-name=Phoenix --minify --outfile=../priv/static/phoenix.min.js)]
