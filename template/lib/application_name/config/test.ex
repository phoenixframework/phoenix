defmodule <%= application_module %>.Config.Test
  use <%= application_module %>.Config

  config :router, port: 4001

  config :plugs, code_reload: true

  config :logger, level: :debug
end


