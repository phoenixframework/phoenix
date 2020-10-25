import Config

# Do not print debug messages in production
config :logger, level: :info

# Finally import the config/runtime.exs which loads secrets
# and configuration from environment variables.
import_config "runtime.exs"
