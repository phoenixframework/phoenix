use Mix.Config

config :phoenix, <%= application_module %>.Router,
  http: [port: System.get_env("PORT") || 4001]
