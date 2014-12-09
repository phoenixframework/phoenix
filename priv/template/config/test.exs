use Mix.Config

config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: System.get_env("PORT") || 4001]
