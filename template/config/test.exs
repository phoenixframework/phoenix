use Mix.Config

config :phoenix, <%= application_module %>.Router,
  port: System.get_env("PORT") || 4001,
  ssl: false,
  cookies: true,
  session_key: "_<%= application_name %>_key",
  secret_key_base: "<%= secret_key_base %>"

config :phoenix, :code_reloader,
  enabled: true

config :logger, :console,
  level: :debug


