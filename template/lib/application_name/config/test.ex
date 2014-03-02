defmodule <%= application_module %>.Config.Test do
  use <%= application_module %>.Config

  config :router, port: 4001,
                  ssl: false

  config :plugs, code_reload: true

  config :logger, level: :debug
end


