defmodule <%= application_module %>.Config.Dev
  use <%= application_module %>.Config

  config :router, port: 4000

  config :plugs, code_reload: true

  config :logger, level: :debug
end


