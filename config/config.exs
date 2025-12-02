import Config

config :logger, :console,
  colors: [enabled: false],
  format: "\n$time $metadata[$level] $message\n"

config :phoenix,
  # TODO: Remove the `json_library` check once `JSON` becomes the standard `Phoenix.json_library/1`
  json_library: (if Code.ensure_loaded?(JSON), do: JSON, else: Jason),
  stacktrace_depth: 20,
  trim_on_html_eex_engine: false,
  sort_verified_routes_query_params: true

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: ~w(./js/phoenix --bundle) ++ args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.25.4",
    module: esbuild.(~w(--format=esm --sourcemap --outfile=../priv/static/phoenix.mjs)),
    main: esbuild.(~w(--format=cjs --sourcemap --outfile=../priv/static/phoenix.cjs.js)),
    cdn:
      esbuild.(
        ~w(--target=es2016 --format=iife --global-name=Phoenix --outfile=../priv/static/phoenix.js)
      ),
    cdn_min:
      esbuild.(
        ~w(--target=es2016 --format=iife --global-name=Phoenix --minify --outfile=../priv/static/phoenix.min.js)
      )
end
