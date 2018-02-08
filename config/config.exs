use Mix.Config

# Disable colors during tests.
config :logger, :console, colors: [enabled: false]

# Use higher stacktrace depth.
config :phoenix, :stacktrace_depth, 20

config :phoenix, :json_library, Jason
