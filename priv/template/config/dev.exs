use Mix.Config

config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  cache_static_lookup: false,
  reloadable_paths: ["--elixirc-paths", "web"]

# Enables code reloading for development
config :phoenix, :code_reloader, true
