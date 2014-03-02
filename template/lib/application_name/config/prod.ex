defmodule <%= application_module %>.Config.Prod
  use <%= application_module %>.Config

  config :router, port: System.get_env("PORT")

  config :plugs, code_reload: false

  config :logger, level: :error
end


