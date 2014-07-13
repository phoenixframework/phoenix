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


When running in production, use protocol consolidation for increased performance:

       MIX_ENV=prod mix compile.protocols
       MIX_ENV=prod elixir -pa _build/prod/consolidated -S mix phoenix.start

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
    render conn, "show", title: "Showing page #{page}"
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

### Views & Templates

Put simply, Phoenix Views *render* templates. Views also serve as a presentation layer for their templates where functions, alias, imports, etc are in context.

### Rendering from the Controller
```elixir
defmodule App.Controllers.Pages do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index", message: "hello"
  end
end
```

By looking at the controller name `App.Controllers.Pages`, Phoenix will use `App.Views.Pages` to render `lib/app/templates/pages/index.html.eex` within the template `lib/app/templates/layouts/application.html.eex`. Let's break that down:
 * `App.Views.Pages` is the module that will render the template (more on that later)
 * `app` is your application name
 * `templates` is your configured templates directory. See `lib/app/views.ex`
 * `pages` is your controller name
 * `html` is the requested format (more on that later)
 * `eex` is the default renderer
 * `application.html` is the layout because `application` is the default layout name and html is the requested format (more on that later)

Every keyword passed to `render` in the controller is available as an assign within the template, so you can use `<%= @message %>` in the eex template that is rendered in the controller example.

You may also create helper functions within your views or layouts. For exemple, the previous controller will use `App.Views.Pages` so you could have :

```elixir
defmodule App.Views do
  defmacro __using__(_options) do
    quote do
      use Phoenix.View, templates_root: unquote(Path.join([__DIR__, "templates"]))
      import unquote(__MODULE__)

      # This block is expanded within all views for aliases, imports, etc
      alias App.Views

      def title, do: "Welcome to Phoenix!"
    end
  end

  # Functions defined here are available to all other views/templates
end

defmodule App.Views.Pages
  use App.Views

  def display(something) do
    String.upcase(something)
  end
end
```

Which would allow you to use these functions in your template : `<%= display(@message) %>`, `<%= title %>`

Note that all views extend `App.Views`, allowing you to define functions, aliases, imports, etc available in all templates.

To read more about eex templating, see the [elixir documentation](http://elixir-lang.org/docs/stable/eex/).

#### More on request format

The template format to render is chosen based on the following priority:

 * `format` query string parameter, ie `?format=json`
 * The request header `accept` field, ie "text/html"
 * Fallback to html as default format, therefore rendering `*.html.eex`

Note that the layout and view templates would be chosen by matching conten types, ie `application.[format].eex` would be used to render `show.[format].eex`.

See [this file](https://github.com/phoenixframework/phoenix/blob/master/lib/phoenix/mimes.txt) for a list of supported mime types.

#### More on layouts

The "Layouts" module name is hardcoded. This means that `App.Views.Layouts` will be used and, by default, will render templates from `lib/app/templates/layouts`.

The layout template can be changed easily from the controller. For example :

```elixir
defmodule App.Controllers.Pages do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index", message: "hello", layout: "plain"
  end
end
```

To render the template's content inside a layout, use the assign `<%= @inner %>` that will be generated for you.

You may also omit using a template with the following:

```elixir
render "index", message: "hello", layout: nil
```

### Channels

Channels broker websocket connections and integrate with the Topic PubSub layer for message broadcasting. You can think of channels as controllers, with two differences: they are bidirectionnal and the connection stays alive after a reply.

We can implement a channel by creating a module in the _channels_ directory and by using `Phoenix.Channels`:

```elixir
defmodule App.Channels.MyChannel do
  use Phoenix.Channels
end
```

The first thing to do is to implement the join function to authorize sockets on this Channel's topic:


```elixir
defmodule App.Channels.MyChannel do
  use Phoenix.Channels

  def join(socket, "topic", message) do
    {:ok, socket}
  end

  def join(socket, _no, _message) do
    {:error, socket, :unauthorized}
  end

end
```
`join` events are specially treated. When `{:ok, socket}` is returned from the Channel, the socket is subscribed to the channel and authorized to pubsub on the channel/topic pair. When `{:error, socket, reason}` is returned, the socket is denied pubsub access.

Note that we must join a topic before you can send and receive events on a channel. This will become clearer when we look at the JavaScript code, hang tight!

A channel will use a socket underneath to send responses and receive events. As said, sockets are bidirectionnal, which mean you can receive events (similar to requests in your controller). You handle events with pattern matching, for example:


```elixir
defmodule App.Channels.MyChannel do
  use Phoenix.Channels

  def event(socket, "user:active", %{user_id: user_id}) do
    socket
  end

  def event(socket, "user:idle", %{user_id: user_id}) do
    socket
  end

end
```

We can send replies directly to a single authorized socket with `reply/3`

```elixir
defmodule App.Channels.MyChannel do
  use Phoenix.Channels

  def event(socket, "eventname", message) do
    reply socket, "return_event", "Echo: " <> message
    socket
  end

end
```

Note that, for added clarify, events should be prefixed by their subject and a colon (i.e. "subject:event"). Instead of `reply/3`, you may also use `broadcast/3`. In the previous case, this would publish a message to all clients who previously joined the current socket's topic.

Remember that a client first has to join a topic before it can send events. On the JavaScript side, this is how it would be done (don't forget to include _/static/js/phoenix.js_) :

```js
var socket = new Phoenix.socket("ws://" + location.host + "/ws");

socket.join("channel", "topic", callback);
```

First you create a socket which uses the ws:// protocol and the host from the current location and it appends the route /ws. This route's name is for you to decide in your router :

```elixir
defmodule App.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/ws"

  channel "channel", App.Channels.MyChannel
end
```

This mounts the socket router on /ws and also register the channel from earlier as `channel`. Let's recap:

 * The mountpoint for the socket in the router (/ws) has to match the route used on the JavaScript side when creating the new socket.
 * The channel name in the router has to match the first parameter on the JavaScript call to `socket.join`
 * The name of the topic used in `def join(socket, "topic", message)` function has to match the second parameter on the JavaScript call to `socket.join`

Now that a channel exists and we have reached it, it's time to do something fun with it! The callback from the previous JavaScript example receives the channel as a parameter and uses that to either subscribe to topics or send events to the server. Here is a quick example of both :

```js
var socket = new Phoenix.socket("ws://" + location.host + "/ws");

socket.join("channel", "topic", function(channel) {

  channel.on("join", function(message) {
    console.log("joined successfully");
  });

  channel.on("return_event", function(message) {
    console.log("Got " + message + " while listening for event return_event");
  });

  onSomeEvent(function() {
    channel.send("topic:event", {data: "json stuff"});
  });

});
```

There are a few other this not covered in this readme that might be worth exploring :

 * Both the client and server side allow for leave events (as opposed to join)
 * In JavaScript, you may manually `.trigger()` events which can be useful for testing
 * On the server side, string topics are converted into a `Topic`, which can be subscribed to from any elixir code. No need to use websockets!

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

### Building phoenix.coffee

```bash
$ coffee -o priv/static/js -cw priv/src/static/cs
```


### Building documentation

1. Clone [docs repository](https://github.com/phoenixframework/docs) into `../docs`. Relative to your `phoenix` directory.
2. Run `MIX_ENV=docs mix run release_docs.exs` in `phoenix` directory.
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
  - [ ] I18n
- Realtime
  - [x] Websocket multiplexing/channels

