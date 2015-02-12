use Mix.Config

# Enable code reloading as we need it for tests.
config :phoenix, :code_reloader, true

# Disable colors during tests.
config :logger, :console, colors: [enabled: false]
