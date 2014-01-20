# Phoenix

```elixir
defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", PagesController, :show, as: :page
  resources "users", UsersController
end

defmodule PagesController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Hello!"
  end
end

defmodule UsersController do
  use Phoenix.Controller

  def show(conn) do
    text conn, "Show user!"
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

