# Phoenix

> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)

## Getting started

### Requirements
- Elixir v0.14.2

### Setup
1. Install Phoenix

        git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && git checkout v0.3.0 && mix do deps.get, compile


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

  def show(conn, %{"page" => "admin"}) do
    redirect conn, Router.page_path(page: "unauthorized")
  end
  def show(conn, %{"page" => page}) do
    render conn, title: "Showing page #{page}"
  end

end

defmodule Controllers.Users do
  use Phoenix.Controller

  def show(conn, %{"id" => id}) do
    text conn, "Showing user #{id}"
  end

  def index(conn, _params) do
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

### Using views

```elixir
defmodule App.Controllers.Pages do
  use Phoenix.Controller

  def index(conn, _params) do
    render "index", message: "hello"
  end
end
```

This will use `App.Views.Pages` to render `lib/app/templates/pages/index.html.eex` within the template `lib/app/templates/layouts/application.html.eex`. Let's break that down: 
 * `App.Views.Pages` is the module that will render the template (more on that later)
 * `app` is you application name
 * `templates` is your configured templates directory. See `lib/app/views.ex` to change it
 * `pages` is your controller name
 * `html` is the requested format (more on that later)
 * `eex` is the default renderer
 * `application.html` is the layout because `application` is the default layout name and html is the requested format (more on that later)

This will also create an assign for `message`, so you can use `<%= @message %>` in your eex template.

You may also create helper functions within your views or layouts. For exemple, the previous controller will use `App.Views.Pages` so you could have : 

```elixir
defmodule App.Views.Pages
  use App.Views

  def display(something) do 
    something
  end
end
```

Which would allow you to use this function in your template : `<%= display(@message) %>`. 

Note that all views extend `App.Views` which is defined in `lib/app/views.ex`, thus allowing you to define functions available in all templates.

To read more about eex templating, see the [elixir documentation](http://elixir-lang.org/docs/stable/eex/). 

#### More on request format

By default, html will be used as the format, therefore rendering `*.html.eex`. You can change it in two ways: 
 * Add `?format=[format]` to your query string
 * Change the request header `accept` field.

Note that a matching `application.[format].eex` would be used to render `aview.[format].eex`.

See [this file](https://github.com/phoenixframework/phoenix/blob/master/lib/phoenix/mimes.txt) for a list of supported mime types.

#### More on layouts

The "Layouts" module name is hardcoded. This means that `App.Views.Layouts` will be used and, by default, will render templates from `lib/app/templates/layouts`. You cannot delete this view, but you could delete all of its templates in theory.

The template name (application) can be changed easily from the controller. For example : 

```elixir
defmodule App.Controllers.Pages do
  use Phoenix.Controller

  def index(conn, _params) do
    render "index", message: "hello", layout: "not-application"
  end
end
```

To render the template's content inside a layout, use the assign `<%= @inner %>` that will be generated for you.

You may also omit using a template with the following : 

```elixir
render "index", message: "hello", within: nil
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

#### Configuration for Sessions

Phoenix supports a session cookie store that can be easily configured. Just
add the following configuration settings to your application's config module:

```elixir
# your_app/lib/config/prod.ex
defmodule YourApp.Config.Prod do
  use YourApp.Config

  config :plugs, cookies: true

  config :cookies, key: "_your_app_key", secret: "valid_secret"
end
```

Then you can access session data from your application controllers.
NOTE: that `:key` and `:secret` are required options.

Example:

```elixir
defmodule Controllers.Pages do
  use Phoenix.Controller

  def show(conn, _params) do
    conn = put_session(:foo, "bar")
    foo = get_session(conn, :foo)

    text conn, foo
  end
end
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

API documentation is available at [http://api.phoenixframework.org/](http://api.phoenixframework.org/)


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
  - [ ] ExConf integreation with config.exs
- Middleware
  - [x] Plug Based Connection handling
  - [x] Code Reloading
  - [ ] Enviroment Based logging with log levels
  - [x] Static File serving
- Controllers
  - [x] html/json/text helpers
  - [x] redirects
  - [ ] Plug layer for action hooks
  - [x] Error page handling
  - [ ] Error page handling per env
- Views
  - [x] Precompiled View handling
- Realtime
  - [x] Websocket multiplexing/channels

