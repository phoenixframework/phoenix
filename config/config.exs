import Config

config :logger, :console, colors: [enabled: false]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :json_library, Jason

config :phoenix, :trim_on_html_eex_engine, false

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: ~w(./js/phoenix --bundle) ++ args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.13.4",
    module: esbuild.(~w(--format=esm --sourcemap --outfile=../priv/static/phoenix.esm.js)),
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
