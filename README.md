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
       MIX_ENV=prod PORT=4001 elixir -pa _build/prod/consolidated -S mix phoenix.start

### Router example

```elixir
defmodule YourApp.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :your_app

  scope alias: YourApp do
    get "/pages/:page", PageController, :show, as: :page
    get "/files/*path", FileController, :show
    
    resources "users", UserController do
    resources "comments", CommentController
    end
  end

  scope path: "admin", alias: YourApp.Admin, helper: "admin" do
    resources "users", UserController
  end
end
```

### Controller examples

```elixir
defmodule YourApp.PageController do
  use Phoenix.Controller

  def show(conn, %{"page" => "admin"}) do
    redirect conn, Router.page_path(page: "unauthorized")
  end
  def show(conn, %{"page" => page}) do
    render conn, "show", title: "Showing page #{page}"
  end

end

defmodule YourApp.UserController do
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
defmodule App.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index", message: "hello"
  end
end
```

By looking at the controller name `App.PageController`, Phoenix will use `App.PageView` to render `lib/app/templates/page/index.html.eex` within the template `lib/app/templates/layout/application.html.eex`. Let's break that down:
 * `App.PageView` is the module that will render the template (more on that later)
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

defmodule App.PageView
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

See [this file](https://github.com/elixir-lang/plug/blob/master/lib/plug/mime.types) for a list of supported mime types.

#### More on layouts

The "Layouts" module name is hardcoded. This means that `App.Views.Layouts` will be used and, by default, will render templates from `lib/app/templates/layouts`.

The layout template can be changed easily from the controller. For example :

```elixir
defmodule App.PageController do
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

### Template Engine Configuration

By default, `eex` and `haml` are supported (with an optional `calliope` dep). To add `haml` support, simply 
include the following in your `mix.exs` deps:

```elixir
{:calliope, "~> 0.2.4"}
```

To configure a third-party Phoenix template engine, add the extension and module to your Mix Config, ie:

```elixir
config :phoenix, :template_engines,
  slim: Slim.PhoenixEngine
```

### Topics

Topics provide a simple publish/subscribe mechanism that can be used to facilitate messaging between components in an application. To subscribe a process to a given topic, call `subscribe/2` passing in the PID and a string to identify the topic:

```elixir
Phoenix.Topic.subscribe self, "foo"
```

Then, to broadcast messages to all subscribers to that topic:

```elixir
Phoenix.Topic.broadcast "foo", { :message_type, some: 1, data: 2 }
```

For example, let's look at a rudimentary logger that prints messages when a controller action is invoked:

```elixir
defmodule Logger do
  def start_link do
    sub = spawn_link &(log/0)
    Phoenix.Topic.subscribe(sub, "logging")
    {:ok, sub}
  end

  def log do
    receive do
      { :action, params } ->
        IO.puts "Called action #{params[:action]} in controller #{params[:controller]}"
      _ ->
    end
    log
  end
end
```

With this module added as a worker to the app's supervision tree, we can broadcast messages to the `"logging"` topic, and they will be handled by the logger:

```elixir
def index(conn, _params) do
  Phoenix.Topic.broadcast "logging", { :action, controller: "pages", action: "index" }
  render conn, "index"
end
```

### Channels

Channels broker websocket connections and integrate with the Topic PubSub layer for message broadcasting. You can think of channels as controllers, with two differences: they are bidirectionnal and the connection stays alive after a reply.

We can implement a channel by creating a module in the _channels_ directory and by using `Phoenix.Channels`:

```elixir
defmodule App.MyChannel do
  use Phoenix.Channel
end
```

The first thing to do is to implement the join function to authorize sockets on this Channel's topic:


```elixir
defmodule App.MyChannel do
  use Phoenix.Channel

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
defmodule App.MyChannel do
  use Phoenix.Channel

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
defmodule App.MyChannel do
  use Phoenix.Channel

  def event(socket, "eventname", message) do
    reply socket, "return_event", "Echo: " <> message
    socket
  end

end
```

Note that, for added clarity, events should be prefixed by their subject and a colon (i.e. "subject:event"). Instead of `reply/3`, you may also use `broadcast/3`. In the previous case, this would publish a message to all clients who previously joined the current socket's topic.

Remember that a client first has to join a topic before it can send events. On the JavaScript side, this is how it would be done (don't forget to include _/static/js/phoenix.js_) :

```js
var socket = new Phoenix.Socket("ws://" + location.host + "/ws");

socket.join("channel", "topic", {some_auth_token: "secret"}, callback);
```

First you create a socket which uses the ws:// protocol and the host from the current location and it appends the route /ws. This route's name is for you to decide in your router :

```elixir
defmodule App.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/ws"

  channel "channel", App.MyChannel
end
```

This mounts the socket router on /ws and also register the channel from earlier as `channel`. Let's recap:

 * The mountpoint for the socket in the router (/ws) has to match the route used on the JavaScript side when creating the new socket.
 * The channel name in the router has to match the first parameter on the JavaScript call to `socket.join`
 * The name of the topic used in `def join(socket, "topic", message)` function has to match the second parameter on the JavaScript call to `socket.join`

Now that a channel exists and we have reached it, it's time to do something fun with it! The callback from the previous JavaScript example receives the channel as a parameter and uses that to either subscribe to topics or send events to the server. Here is a quick example of both :

```js
var socket = new Phoenix.Socket("ws://" + location.host + "/ws");

socket.join("channel", "topic", {}, function(channel) {

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

Phoenix provides a configuration per environment set by the `MIX_ENV` environment variable. The default environment `dev` will be set if `MIX_ENV` does not exist.

#### Configuration file structure:
```
├── your_app/config/
│   ├── config.exs          Base application configuration
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
```

```elixir
# your_app/config/config.exs
use Mix.Config

config :phoenix, YourApp.Router,
  port: System.get_env("PORT"),
  ssl: false,
  code_reload: false,
  cookies: true,
  session_key: "_your_app_key",
  session_secret: "super secret"

config :phoenix, :logger,
  level: :error


import_config "#{Mix.env}.exs"


# your_app/config/dev.exs
use Mix.Config

config :phoenix, YourApp.Router,
  port: System.get_env("PORT") || 4000,
  ssl: false,
  code_reload: true,
  cookies: true,
  consider_all_requests_local: true,
  session_key: "_your_app_key",
  session_secret: "super secret"

config :phoenix, :logger,
  level: :debug


```

#### Configuration for SSL

To launch your application with support for SSL, just place your keyfile and
certfile in the `priv` directory and configure your router with the following
options:

```elixir
# your_app/config/prod.ex
use Mix.Config

config :phoenix, YourApp.Router,
  port: System.get_env("PORT"),
  ssl: true,
  code_reload: false,
  cookies: true,
  session_key: "_your_app_key",
  session_secret: "super secret"
  otp_app: :your_app,
  keyfile: "ssl/key.pem",
  certfile: "ssl/cert.pem"

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

#### Serving You Application Behind a Proxy

If you are serving your application behind a proxy such as `nginx` or
`apache`, you will want to specify the `proxy_port` option. This will ensure
the route helper functions will not contain the port number.

Example:

```elixir
# your_app/config/prod.ex
use Mix.Config

config :phoenix, YourApp.Router,
  ...
  port: 4000,
  proxy_port: 443
  ...
```

#### Configuration for Sessions

Phoenix supports a session cookie store that can be easily configured. Just
add the following configuration settings to your application's config module:

```elixir
# your_app/config/prod.ex
use Mix.Config

config :phoenix, YourApp.Router,
  ...
  cookies: true,
  session_key: "_your_app_key",
  session_secret: "super secret"
  ...

```

Then you can access session data from your application controllers.
NOTE: that `:key` and `:secret` are required options.

Example:

```elixir
defmodule YourApp.PageController do
  use Phoenix.Controller

  def show(conn, _params) do
    conn = fetch_session(conn) |> put_session(:foo, "bar")
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
  - [x] Integration with config.exs
- Middleware
  - [x] Plug Based Connection handling
  - [x] Code Reloading
  - [ ] Enviroment Based logging with log levels with Elixir's Logger
  - [x] Static File serving
- Controllers
  - [x] html/json/text helpers
  - [x] redirects
  - [x] Plug layer for action hooks
  - [x] Error page handling
  - [ ] Error page handling per env
- Views
  - [x] Precompiled View handling
  - [x] I18n
- Realtime
  - [x] Websocket multiplexing/channels
  - [x] Browser js client
  - [ ] iOS client (WIP)
  - [ ] Android client

