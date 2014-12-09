use Mix.Config

config :phoenix, <%= application_module %>.Endpoint,
  http: [port: System.get_env("PORT") || 4001]
