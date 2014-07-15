use Mix.Config

config :phoenix,
  routers: [
    [endpoint: <%= application_module %>.Router,
     port: 4001,
     ssl: false,
     consider_all_requests_local: true,
     plugs: [code_reload: true,
             parsers: true,
             error_handler: true,
             cookies: true]
    ]
  ],
  logger: [
    level: :debug
  ]




