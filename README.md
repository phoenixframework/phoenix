# Phoenix

Realtime Elixir Web Framework

## Getting started

1. Install Phoenix

        git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && mix do deps.get, compile


2. Create a new Phoenix application

        mix phoenix.new your_app /path/to/scaffold/your_app

    *Important*: Run task from your installation directory. Note that `/path/to/scaffold/your_app` should not be inside the phoenix repo. Instead, provide a relative or fully-qualified path outside of the phoenix repository.

3. Change directory to `/path/to/scaffold/your_app`. Install dependencies and start web server
        
        mix deps.get
        mix run -e 'Router.start' --no-halt mix.exs


### Router example

```elixir
defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", Controllers.Pages, :show, as: :page
  get "files/*path", Controllers.Files, :show
  get "profiles/user-:id", Controllers.Users, :show

  resources "users", Controllers.Users do
    resources "comments", Controllers.Comments
  end

  scope path: "admin", alias: Controllers.Admin, helper: "admin" do
    resources "users", Users
  end
end
```

### Controller examples

```elixir
defmodule Controllers.Pages do
  use Phoenix.Controller

  def show(conn) do
    if conn.params["page"] in ["admin"] do
      redirect conn, Router.page_path(page: "unauthorized")
    else
      text conn, "Showing page #{conn.params["page"]}"
    end
  end

end

defmodule Controllers.Users do
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

### Mix Tasks

```console
mix phoenix                                    # List Phoenix tasks
mix phoenix.new     app_name destination_path  # Creates new Phoenix application
mix phoenix.routes  [MyApp.Router]             # Prints routes
mix phoenix --help                             # This help
```

## Documentation

API documentaion is available at [http://phoenixframework.github.io/docs/](http://phoenixframework.github.io/docs/)






## Development

There are no guidelines yet. Do what feels natural. Submit a bug, join a discussion, open a pull request.

### Building documentation

Clone [docs repository](https://github.com/phoenixframework/docs) into `../docs` relative to your `phoenix` directory. Run `mix run release_docs.exs` in `phoenix` directory, go to `../docs` directory, commit and push docs.
