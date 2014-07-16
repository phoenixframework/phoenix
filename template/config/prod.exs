use Mix.Config

config :phoenix,
  routers: [
    [
      endpoint: <%= application_module %>.Router,
      port: System.get_env("PORT"),
      ssl: false,
      plugs: [
        code_reload: false,
        cookies: true
      ],
      cookies: [
        key: "_<%= Mix.Utils.underscore(application_module) %>_key",
        secret: "<%= session_secret %>"
      ]
    ]
  ],
  logger: [
    level: :error
  ]

