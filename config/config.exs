import Config

config :logger, :console, colors: [enabled: false]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :json_library, Jason

config :phoenix, :trim_on_html_eex_engine, false
