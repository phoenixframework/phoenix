use Mix.Config

config :phoenix, <%= application_module %>.Router,
  port: System.get_env("PORT") || 4001,
  ssl: false,
  code_reload: false,
  cookies: true,
  consider_all_requests_local: true,
  session_key: "_<%= application_name %>_key",
  session_secret: "<%= session_secret %>"

config :phoenix, :logger,
  level: :debug


