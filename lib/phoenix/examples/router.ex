defmodule MyApp.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/ws"

  plug Plug.Static, at: "/static", from: :phoenix

  scope alias: Phoenix.Examples.Controllers do
    get "/pages/:page", Pages, :show, as: :page
    get "/files/*path", Files, :show, as: :file
    get "/profiles/user-:id", Users, :show

    resources "users", Users do
      resources "comments", Comments
    end

    raw_websocket "/echo", Eco

  end

  channel Phoenix.Examples.Controllers.Messages

  # def match(socket, :websocket, "messages", event, message) do
  #   apply(Controllers.Messaegs, :event, [event, req, id]
  # end
end

"""
channel.join "messages", (resp) ->

"""

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
