defmodule Phoenix.Router.LiveReload do
  use Phoenix.Router

  @external_resource phx_js_path = "priv/static/phoenix.js"
  @phoenix_js File.read!(phx_js_path)

  def call(%Plug.Conn{path_info: ["phoenix"]} = conn, opts) do
    conn
    |> super(opts)
    |> halt
  end
  def call(conn, _opts) do
    if conn.private.phoenix_endpoint.config(:live_reload) != [] do
      before_send_inject_reloader(conn)
    else
      conn
    end
  end

  socket "/phoenix" do
    channel "phoenix", Phoenix.Channel.ControlChannel
  end

  defp before_send_inject_reloader(conn) do
    register_before_send conn, fn conn ->
      if conn |> get_resp_header("content-type") |> html_content_type? do
        [page | rest] = String.split(to_string(conn.resp_body), "</body>")
        body = page <> reload_assets_tag(conn) <> Enum.join(["</body>" | rest], "")

        put_in conn.resp_body, body
      else
        conn
      end
    end
  end
  defp html_content_type?([]), do: false
  defp html_content_type?([type | _]), do: String.starts_with?(type, "text/html")

  defp reload_assets_tag(conn) do
    config = conn.private.phoenix_endpoint.config(:live_reload)
    url = Path.join((config[:url] || "/"), "phoenix")
    """
    <script>
      #{@phoenix_js}
      var phx = require("phoenix")
      var socket = new phx.Socket("#{url}")
      socket.connect()
      socket.join("phoenix", {}, function(chan){
        chan.on("assets:change", function(msg){ window.location.reload(); })
      })
    </script>
    """
  end
end
