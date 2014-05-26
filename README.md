# Phoenix

> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)

## Getting started

1. Install Phoenix

        git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && mix do deps.get, compile


2. Create a new Phoenix application

        mix phoenix.new your_app /path/to/scaffold/your_app
        
    *Important*: Run this task in the Phoenix installation directory cloned in the step above. The path provided: `/path/to/scaffold/your_app/` should be outside of the framework installation directory. This will either create a new application directory or install the application into an existing directory.
    
    #### Examples:
        mix phoenix.new your_app /Users/you/projects/my_app
        mix phoenix.new your_app ../relative_path/my_app

3. Change directory to `/path/to/scaffold/your_app`. Install dependencies and start web server

        mix do deps.get, compile
        mix phoenix.start


### Router example

```elixir
defmodule YourApp.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :your_app

  get "/pages/:page", Controllers.Pages, :show, as: :page
  get "/files/*path", Controllers.Files, :show

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

### Configuration

Phoenix provides a configuration per environment set by the `MIX_ENV` environment variable. The default environment `Dev` will be set if `MIX_ENV` does not exist.

#### Configuration file structure:
```
├── your_app/lib/config/
│   ├── config.ex          Base application configuration
│   ├── dev.ex
│   ├── prod.ex
│   └── test.ex
```

```elixir
# your_app/lib/config/config.ex
defmodule YourApp.Config do
  use Phoenix.Config.App

  config :router, port: System.get_env("PORT")
  config :plugs, code_reload: false
  config :logger, level: :error
end

# your_app/lib/config/dev.ex
defmodule YourApp.Config.Dev do
  use YourApp.Config

  config :router, port: 4000
  config :plugs, code_reload: true
  config :logger, level: :debug
end
```

#### Configuration for SSL

To launch your application with support for SSL, just place your keyfile and
certfile in the `priv` directory and configure your router with the following
options:

```elixir
# your_app/lib/config/prod.ex
defmodule YourApp.Config.Prod do
  use YourApp.Config

  config :router, port: 4040,
                  ssl: true,
		  otp_app: :your_app,
		  keyfile: "ssl/key.pem",
		  certfile: "ssl/cert.pem"
end
```

When you include the `otp_app` option, `Plug` will search within the `priv`
directory of your application. If you use relative paths for `keyfile` and
`certfile` and do not include the `otp_app` option, `Plug` will throw an error.

You can leave out the `otp_app` option if you provide absolute paths to the
files.

Example:

```elixir
Path.expand("../../../some/path/to/ssl/key.pem", __DIR__)
```

### Mix Tasks

```console
mix phoenix                                    # List Phoenix tasks
mix phoenix.new     app_name destination_path  # Creates new Phoenix application
mix phoenix.routes  [MyApp.Router]             # Prints routes
mix phoenix.start   [MyApp.Router]             # Starts worker
mix phoenix --help                             # This help
```

### Static Assets
Static asset support can be added by including `Plug.Static` in your router. Static assets will be served
from the `priv/static/` directory of your application.

```elixir
  plug Plug.Static, at: "/static", from: :your_app
```

## Documentation

API documentaion is available at [http://api.phoenixframework.org/](http://api.phoenixframework.org/)


## Development

There are no guidelines yet. Do what feels natural. Submit a bug, join a discussion, open a pull request.

### Building documentation

1. Clone [docs repository](https://github.com/phoenixframework/docs) into `../docs`. Relative to your `phoenix` directory.
2. Run `mix run release_docs.exs` in `phoenix` directory.
3. Change directory to `../docs`.
4. Commit and push docs.


## Feature Roadmap
- Robust Routing DSL
  - [x] GET/POST/PUT/PATCH/DELETE macros
  - [x] Named route helpers
  - [x] resource routing for RESTful endpoints
  - [x] Scoped definitions
  - [ ] Member/Collection resource  routes
- Configuration
  - [x] Environment based configuration with ExConf
- Middleware
  - [x] Plug Based Connection handling
  - [x] Code Reloading
  - [ ] Enviroment Based logging with log levels
  - [x] Static File serving
- Controllers
  - [x] html/json/text helpers
  - [x] redirects
  - [x] Error page handling
  - [ ] Error page handling per env
- Views
  - [ ] Precompiled View handling
- Realtime
  - [x] Websocket multiplexing/channels

