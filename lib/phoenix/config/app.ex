defmodule Phoenix.Config.App do
  use ExConf.Config, env_var: "MIX_ENV"

  config :router, port: 4000,
                  ssl: true,
                  # Full error reports are disabled
                  consider_all_requests_local: false

  config :plugs, code_reload: false,
                 serve_static_assets: true,
                 cookies: false

  config :logger, level: :error
end
