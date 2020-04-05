defmodule <%= endpoint_module %> do
  use Phoenix.Endpoint, otp_app: :<%= web_app_name %>

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_<%= web_app_name %>_key",
    signing_salt: "<%= signing_salt %>"
  ]

  socket "/socket", <%= web_namespace %>.UserSocket,
    websocket: true,
    longpoll: false<%= if live || dashboard do %>

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]<% end %>

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :<%= web_app_name %>,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do<%= if html do %>
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader<% end %>
    plug Phoenix.CodeReloader<%= if ecto do %>
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :<%= web_app_name %><% end %>
  end<%= if dashboard do %>

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"<% end %>

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug <%= web_namespace %>.Router
end
