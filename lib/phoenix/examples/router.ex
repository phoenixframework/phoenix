defmodule MyApp.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :phoenix

  scope alias: Phoenix.Examples.Controllers do
    get "/pages/:page", Pages, :show, as: :page
    get "/files/*path", Files, :show, as: :file
    get "/profiles/user-:id", Users, :show

    resources "users", Users do
      resources "comments", Comments
    end
  end
end

defmodule MyApp.Config do
  use Phoenix.Config.App

  config :router, port: 4000

  config :plugs, code_reload: false

end

defmodule MyApp.Config.Dev do
  use MyApp.Config

  config :router, port: System.get_env("PORT") || 4000

  config :plugs, code_reload: true

  config :logger, level: :debug
end
