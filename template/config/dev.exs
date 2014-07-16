use Mix.Config

config :phoenix,
  routers: [
    [
      endpoint: <%= application_module %>.Router,
      port: 4000,
      ssl: false,
      plugs: [
        code_reload: true,
        cookies: true
      ],
      cookies: [
        key: "_<%= Mix.Utils.underscore(application_module) %>_key",
        secret: "<%= session_secret %>"
      ]
    ]
  ],
  logger: [
    level: :debug
  ]

