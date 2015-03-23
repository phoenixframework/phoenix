defmodule Phoenix.Router.LiveReload do
  use Phoenix.Router

  @moduledoc """
  Router for live-reload detection in development.

  This Router is invoked in development from the `Phoenix.CodeReloader` plug.

  ## Configuration
  For live-reloading in development, add the following `:live_reload`
  configuration to your Endpoint with a list of patterns to watch for changes:

   config :my_app, MyApp.Endpoint,
     ...
     live_reload: [
       patterns: [
         ~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
         ~r{web/views/.*(ex)$},
         ~r{web/templates/.*(eex)$}
       ]
     ]


  By default the URL of the live-reload connection will use the browser's
  host and port. To override this, you can pass the `:url` option, ie:

   config :my_app, MyApp.Endpoint,
     ...
     live_reload: [
       url: "ws://localhost:4000",
       patterns: [
         ~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
         ~r{web/templates/.*(eex)$}
       ]
     ]

  """

  def call(%Plug.Conn{path_info: ["phoenix" | _rest]} = conn, opts) do
    conn
    |> super(opts)
    |> halt
  end
  def call(conn, _opts) do
    if conn.private.phoenix_endpoint.config(:live_reload)[:patterns] != [] do
      before_send_inject_reloader(conn)
    else
      conn
    end
  end

  socket "/phoenix" do
    channel "phoenix", Phoenix.Channel.ControlChannel
  end

  get "/phoenix/live-reloader", Phoenix.Router.LiveReload.Controller, :show

  defp before_send_inject_reloader(conn) do
    register_before_send conn, fn conn ->
      if conn |> get_resp_header("content-type") |> html_content_type? do
        [page | rest] = String.split(to_string(conn.resp_body), "</body>")
        body = page <> reload_assets_tag() <> Enum.join(["</body>" | rest], "")

        put_in conn.resp_body, body
      else
        conn
      end
    end
  end
  defp html_content_type?([]), do: false
  defp html_content_type?([type | _]), do: String.starts_with?(type, "text/html")

  defp reload_assets_tag() do
    """
    <iframe src="/phoenix/live-reloader" width="0" height="0" scrolling="no" frameborder="0"></iframe>
    """
  end
end

defmodule Phoenix.Router.LiveReload.Controller do
  use Phoenix.Controller

  @external_resource phx_js_path = "priv/static/phoenix.js"
  @phoenix_js File.read!(phx_js_path)

  def call(conn, _) do
    config = conn.private.phoenix_endpoint.config(:live_reload)
    url = Path.join(config[:url] || "/", "phoenix")

    html conn, """
      <html><body>
      <script>
        #{@phoenix_js}
        var phx = require("phoenix")
        var socket = new phx.Socket("#{url}")
        socket.connect()
        socket.join("phoenix", {}, function(chan){
          chan.on("assets:change", function(msg){
            chan.off("assets:change")
            window.top.location.reload()
          })
        })
      </script>
      </body></html>
    """
  end
end
