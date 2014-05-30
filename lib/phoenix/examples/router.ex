defmodule Examples.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/ws"

  plug Plug.Static, at: "/static", from: :phoenix

  get "/", Phoenix.Examples.Controllers.Pages, :show
  scope alias: Phoenix.Examples.Controllers do
    get "/pages/:page", Pages, :show, as: :page
    get "/files/*path", Files, :show, as: :file
    get "/profiles/user-:id", Users, :show

    resources "users", Users do
      resources "comments", Comments
    end
  end

  channel "messages", Phoenix.Examples.Controllers.Messages
end

defmodule Examples.Config do
  use Phoenix.Config.App

  config :router, port: 4000,
                  host: "example.com"

  config :plugs, code_reload: false

end

defmodule Examples.Config.Dev do
  use Examples.Config

  config :router, port: System.get_env("PORT") || 4000

  config :plugs, code_reload: true

  config :logger, level: :debug
end

defmodule Examples.Config.Prod do
  use Examples.Config

  config :router, port: System.get_env("PORT") || 4040,
                  ssl: true,
                  keyfile:  Path.expand("../../../test/fixtures/ssl/key.pem", __DIR__),
                  certfile: Path.expand("../../../test/fixtures/ssl/cert.pem", __DIR__)

  config :plugs, code_reload: false

  config :logger, level: :error
end
