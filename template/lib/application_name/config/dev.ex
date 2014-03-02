defmodule <%= application_module %>.Config.Dev do
  use <%= application_module %>.Config

  config :router, port: 4000,
                  ssl: false

  config :plugs, code_reload: true

  config :logger, level: :debug
end


