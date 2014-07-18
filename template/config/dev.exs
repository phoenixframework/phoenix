use Mix.Config

config :phoenix, <%= application_module %>.Router,
  port: System.get_env("PORT") || 4000,
  ssl: false,
  code_reload: true,
  cookies: true,
  session_key: "_<%= Mix.Utils.underscore(application_module) %>_key",
  session_secret: "<%= session_secret %>"

config :phoenix, :logger,
  level: :debug


