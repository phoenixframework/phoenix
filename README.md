# Phoenix
> Realtime Elixir Web Framework

## Goals
- First class websockets
- Ring distribution

```elixir
defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", PagesController, :show, as: :page
  resources "users", UsersController
end

defmodule PagesController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Hello! #{conn.params["page"]}"
  end
end

defmodule UsersController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Showing user #{conn.params["id"]}"
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
```

## Starting the application

```bash
$ mix run --no-halt mix.exs
```

