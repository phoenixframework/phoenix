use Mix.Config

config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  cache_static_lookup: false,
  watch: ["priv/static/js/app.js", "priv/static/css/phoenix.css"]

# Enables code reloading for development
config :phoenix, :code_reloader, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
