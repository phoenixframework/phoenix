defmodule Phoenix.Examples.Controllers.Pages do
  use Phoenix.Controller

  def show(conn) do
    html conn, File.read!(Path.join(["priv/views/index.html"]))
  end

  def show(_conn, "page") do
  end
end

defmodule Phoenix.Examples.Controllers.Users do
  use Phoenix.Controller

  def show(conn) do
    if conn.params["id"] in ["1", "2", "3"] do
      redirect conn, Router.page_path(page: conn.params["id"])
    else
      text conn, "Showing user #{conn.params["id"]}"
    end
  end

  def index(conn) do
    html conn, """
    <html>
      <body>
        <h1>Users</h1>
      </body>
    </html>
    """
  end
end

defmodule Phoenix.Examples.Controllers.Comments do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Showing comment #{conn.params["id"]} for user #{conn.params["user_id"]}"
  end

  def index(conn) do
    html conn, """
    <html>
      <body>
        <h1>Users</h1>
      </body>
    </html>
    """
  end
end

defmodule Phoenix.Examples.Controllers.Files do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Get file: #{conn.params["path"]}"
  end
end

defmodule Phoenix.Examples.Controllers.Messages do
  use Phoenix.Channel

  def join(socket, _message) do
    IO.puts "JOIN #{socket.channel}:#{socket.topic}"
    reply socket, "join", status: "connected"
    broadcast socket, "user:entered", username: "anonymous"
    {:ok, socket}
  end

  def event("new", socket, message) do
    broadcast socket, "new", message
    socket
  end

end

defmodule Phoenix.Examples.Controllers.Echo do
  # use Phoenix.Websocket.RawHandler

#
#   def join(socket, data) do
#     case authenticate(data) do
#       {:ok, auth_key}  -> reply socket, auth_key: auth_key
#       {:error, reason} -> reply socket, error: reason
#     end
#   end
#
#   def authenticate(data) do
#     {:ok, "xyz"}
#   end
#
#   def leave(socket, reason, state) do
#     broadcast "user:exit", user_id: state.user_id
#   end
#
#   def on(:create, socket, data, _state) do
#     broadcast "create", data
#   end
#
#   def stream(data, socket, _state) do
#     reply socket, data
  # end
end

