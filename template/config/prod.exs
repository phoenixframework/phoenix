use Mix.Config

"""
NOTE: To get SSL working, you will need to set:

    ssl: true,
    keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
    certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),

Where those two env variables point to a file on disk
for the key and cert
"""

config :phoenix, <%= application_module %>.Router,
  port: System.get_env("PORT"),
  ssl: false,
  host: "example.com",
  cookies: true,
  session_key: "_<%= application_name %>_key",
  session_secret: "<%= session_secret %>"

config :logger, :console,
  level: :info,
  metadata: [:request_id]

