defmodule PagesController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Showing page #{conn.params["page"]}!"
  end

  def show(conn, "page") do
  end
end

defmodule UsersController do
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

defmodule CommentsController do
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

defmodule FilesController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Get file: #{conn.params["path"]}"
  end
end

