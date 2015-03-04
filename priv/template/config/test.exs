use Mix.Config

config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: 4001]

# Print only warnings and errors during test
config :logger, level: :warn