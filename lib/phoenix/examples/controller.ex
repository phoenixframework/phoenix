defmodule PagesController do
  use Phoenix.Controller

  def show(conn) do
    {:ok,  conn
           |> Plug.Connection.put_resp_content_type("text/plain")
           |> Plug.Connection.send(200, "Page show!")
    }
  end
end

defmodule UsersController do
  use Phoenix.Controller

  def show(conn) do
    {:ok,  conn
           |> Plug.Connection.put_resp_content_type("text/plain")
           |> Plug.Connection.send(200, "User show!")
    }
  end

  def index(conn) do
    {:ok,  conn
           |> Plug.Connection.put_resp_content_type("text/plain")
           |> Plug.Connection.send(200, "All the users!")
    }
  end
end

defmodule CommentsController do
  use Phoenix.Controller

  def show(conn) do
    user_id = conn.params["user_id"]
    {:ok,  conn
           |> Plug.Connection.put_resp_content_type("text/plain")
           |> Plug.Connection.send(200, "Comment show for user #{user_id}!")
    }
  end

  def index(conn) do
    {:ok,  conn
           |> Plug.Connection.put_resp_content_type("text/plain")
           |> Plug.Connection.send(200, "All the comments!")
    }
  end
end
