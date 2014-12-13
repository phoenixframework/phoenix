![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/images/phoenix.png)
> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

***

- [Getting started](#getting-started)
  - [Requirements](#requirements)
  - [Setup](#setup)
  - [Router example](#router-example)
    - [Resources](#resources)
    - [Method Overrides](#method-overrides)
  - [Controller examples](#controller-examples)
  - [Views & Templates](#views--templates)
  - [Flash Examples](#flash-examples)
  - [Rendering from the Controller](#rendering-from-the-controller)
    - [More on request format](#more-on-request-format)
    - [More on layouts](#more-on-layouts)
  - [Template Engine Configuration](#template-engine-configuration)
  - [PubSub](#pubsub)
  - [Channels](#channels)
    - [Holding state in socket connections](#holding-state-in-socket-connections)
  - [Configuration](#configuration)
    - [Configuration file structure](#configuration-file-structure)
    - [Configuration for SSL](#configuration-for-ssl)
    - [Serving Your Application Behind a Proxy](#serving-your-application-behind-a-proxy)
    - [Configuration for Sessions](#configuration-for-sessions)
  - [Custom Not Found and Error Pages](#custom-not-found-and-error-pages)
    - [Plug.Exception](#plugexception)
  - [Mix Tasks](#mix-tasks)
  - [Static Assets](#static-assets)
- [Documentation](#documentation)
- [Development](#development)
  - [Building phoenix.coffee](#building-phoenixcoffee)
- [Contributing](#contributing)
- [Important links](#important-links)
- [Feature Roadmap](#feature-roadmap)


## Getting started

### Requirements

- Elixir v1.0.2+

### Setup

1. Install Phoenix

        git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && git checkout v0.7.2 && mix do deps.get, compile


2. Create a new Phoenix application

        mix phoenix.new my_app /path/to/scaffold/my_app

    *Important*: Run this task in the Phoenix installation directory cloned in the step above. The path provided: `/path/to/scaffold/my_app/` should be outside of the framework installation directory. This will either create a new application directory or install the application into an existing directory.

    #### Examples:
        mix phoenix.new my_app /Users/you/projects/my_app
        mix phoenix.new my_app ../relative_path/my_app

3. Change directory to `/path/to/scaffold/my_app`. Install dependencies and start web server

        mix do deps.get, compile
        mix phoenix.server


When running in production, use protocol consolidation for increased performance:

       MIX_ENV=prod mix compile.protocols
       MIX_ENV=prod PORT=4001 elixir -pa _build/prod/consolidated -S mix phoenix.server

### Router example

```elixir
defmodule MyApp.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :accepts, ~w(html)
    plug :fetch_session
  end

  pipeline :api do
    plug :accepts, ~w(json)
  end

  scope "/", alias: MyApp do
    pipe_through :browser

    get "/pages/:page", PageController, :show
    get "/files/*path", FileController, :show

    resources "/users", UserController do
      resources "/comments", CommentController
    end
  end

  scope "/api", alias: MyApp.Api do
    pipe_through :api

    resources "/users", UserController
  end
end
```

Routes specified using `get`, `post`, `patch`, and `delete` respond to the corresponding HTTP method. The second and third parameters are the controller module and function, respectively. For example, the line `get "/files/*path", FileController, :show` above will route GET requests matching `/files/*path` to the `FileController.show` function.

#### Resources

The `resources` macro generates a set of routes for the standard CRUD operations, so:

```elixir
resources "/users", UserController
```

is the equivalent of writing:

```elixir
get  "/users",          UserController, :index
get  "/users/:id",      UserController, :show
get  "/users/new",      UserController, :new
post "/users",          UserController, :create
get  "/users/:id/edit", UserController, :edit
patch "/users/:id",     UserController, :update
delete "/users/:id",    UserController, :destroy
```

Resources will also generate a set of named routes and associated helper methods:

```elixir
defmodule MyApp.Router do
  use Phoenix.Router
  ...
  resources "/users", UserController do
    resources "/comments", CommentController
  end
end
```

Executing 'iex -S mix' from your project's root directory will load your project into the shell. Then you can explore the routes interactively.

```elixir
iex> MyApp.Router.Helpers.user_path(:index)
"/users"

iex> MyApp.Router.Helpers.user_path(:show, 123)
"/users/123"

iex> MyApp.Router.Helpers.user_path(:show, 123, page: 5)
"/users/123?page=5"

iex> MyApp.Router.Helpers.user_path(:edit, 123)
"/users/123/edit"

iex> MyApp.Router.Helpers.user_path(:destroy, 123)
"/users/123"

iex> MyApp.Router.Helpers.user_path(:new)
"/users/new"

iex> MyApp.Router.Helpers.user_comment_path(:show, 99, 100)
"/users/99/comments/100"

iex> MyApp.Router.Helpers.user_comment_path(:index, 99, foo: "bar")
"/users/99/comments?foo=bar"

iex> MyApp.Router.Helpers.user_comment_path(:index, 99) |> MyApp.Endpoint.url
"http://example.com/users/99/comments"

iex> MyApp.Router.Helpers.user_comment_path(:edit, 88, 2, [])
"/users/88/comments/2/edit"

iex> MyApp.Router.Helpers.user_comment_path(:new, 88)
"/users/88/comments/new"
```

#### Method Overrides

Since browsers don't allow HTML forms to send PATCH or DELETE requests, Phoenix allows the POST method to be overridden, either by adding a `_method` form parameter, or specifying an `x-http-method-override` HTTP header.

For example, to make a button to delete a post, you could write:

```html
<form action="<%= post_path(:destroy, @post.id) %>" method="post">
  <input type="hidden" name="_method" value="DELETE">
  <input type="submit" value="Delete Post">
</form>
```

### Controller examples

```elixir
defmodule MyApp.PageController do
  use Phoenix.Controller
  import MyApp.Router.Helpers

  plug :action

  def show(conn, %{"page" => "admin"}) do
    redirect conn, to: page_path(:show, "unauthorized")
  end

  def show(conn, %{"page" => page}) do
    conn
    |> assign(:title, "Showing page #{page}")
    |> render("show.html")
  end
end
```

```elixir
defmodule MyApp.UserController do
  use Phoenix.Controller

  plug :locale, default: "en"
  plug :action

  def show(conn, %{"id" => id}) do
    conn
    |> assign(:user_id, id)
    |> render("index.html")
  end

  defp locale(conn, opts) do
    if conn.params["locale"] in ["en", "fr", "de"] do
      assign(conn, :locale, conn.params["locale"])
    else
      assign(conn, :locale, opts[:default])
    end
  end
end
```

### Views & Templates

Put simply, Phoenix Views *render* templates. Views also serve as a presentation layer for their templates where functions, alias, imports, etc are in context.

### Flash Examples

You could use `Phoenix.Controller.Flash` to persist messages across redirects like below.

```elixir
defmodule MyApp.PageController do
  use Phoenix.Controller

  plug :action

  alias Phoenix.Controller.Flash

  def create(conn, _) do
    # Code for some create action here
    conn
    |> Flash.put(:notice, "Created successfully")
    |> redirect("/")
  end
end
```

`Phoenix.Controller.Flash` is automatically aliased in all Views. In your templates,
you would display flash messages by doing something like:

```elixir
# web/templates/layout/application.html.eex
<%= if notice = Flash.get(@conn, :notice) do %>
  <div class="container">
    <div class="row">
      <p><%= notice %></p>
    </div>
  </div>
<% end %>
```

Phoenix also supports multiple flash messages.

```elixir
# web/templates/layout/application.html.eex
<%= for notice <- Flash.get_all(@conn, :notice) do %>
  <div class="container">
    <div class="row">
      <p><%= notice %></p>
    </div>
  </div>
<% end %>
```

### Rendering from the Controller
```elixir
defmodule App.PageController do
  use Phoenix.Controller

  plug :action

  def index(conn, _params) do
    render conn, "index", message: "hello"
  end
end
```

By looking at the controller name `App.PageController`, Phoenix will use `App.PageView` to render `web/templates/page/index.html.eex` within the template `web/templates/layout/application.html.eex`. Let's break that down:
 * `App.PageView` is the module that will render the template (more on that later)
 * `App` is your application name
 * `templates` is your configured templates directory. See `web/view.ex`
 * `page` is your controller name
 * `html` is the requested format (more on that later)
 * `eex` is the default renderer
 * `application.html` is the layout because `application` is the default layout name and html is the requested format (more on that later)

Every keyword passed to `render` in the controller is available as an assign within the template, so you can use `<%= @message %>` in the eex template that is rendered in the controller example.

You may also create helper functions within your views or layouts. For example, the previous controller will use `App.PageView` so you could have :

```elixir
defmodule MyApp.View do
  use Phoenix.View, root: "web/templates"

  # The quoted expression returned by this block is applied
  # to this module and all other views that use this module.
  using do
    quote do
      # Import common functionality
      import MyApp.I18n
      import MyApp.Router.Helpers

      # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
      use Phoenix.HTML

      # Common aliases
      alias Phoenix.Controller.Flash
    end
  end

  # Functions defined here are available to all other views/templates
  def title, do: "Welcome to Phoenix!"
end

defmodule MyApp.PageView do
  use MyApp.View

  def display(something) do
    String.upcase(something)
  end

  def render("show.json", %{page: page}) do
    %{title: page.title, url: page.url}
  end
end
```

Which would allow you to use these functions in your template : `<%= display(@message) %>`, `<%= title %>`

Note that all views extend `MyApp.View`, allowing you to define functions, aliases, imports, etc available in all templates. Additionally, `render/2` functions can be defined to perform rendering directly as function definitions. The arguments to `render/2` are controller action name with the response content-type mime extension.

To read more about eex templating, see the [elixir documentation](http://elixir-lang.org/docs/stable/eex/).

#### More on request format

The template format to render is chosen based on the following priority:

 * `format` query string parameter, ie `?format=json`
 * The request header `accept` field, ie "text/html"
 * Fallback to html as default format, therefore rendering `*.html.eex`

To override the render format, for example when rendering your sitemap.xml, you can explicitly set the response content-type, using `put_resp_content_type/2` and the template will be chosen from the given mime-type, ie:

```elixir
def sitemap(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render(:sitemap)
end
```

Note that using the atom form of the template name `:sitemap`, would render the template based on the response content type, ie `sitemap.[format].eex`.

See [this file](https://github.com/elixir-lang/plug/blob/master/lib/plug/mime.types) for a list of supported mime types.

#### More on layouts

The "LayoutView" module name is hardcoded. This means that `App.LayoutView` will be used and, by default, will render templates from `web/templates/layout`.

The layout template can be changed easily from the controller via `put_layout/2`. For example :

```elixir
defmodule App.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    conn
    |> put_layout("plain")
    |> render("index.html", message: "hello")
  end
end
```

To render the template's content inside a layout, use the assign `<%= @inner %>` that will be generated for you.

You may also omit using a layout with the following:

```elixir
conn |> put_layout(:none) |> render "index", message: "hello"
```

### Template Engine Configuration

By default, `eex` is supported. To add `haml` support, simply
include the following in your `mix.exs` deps:

```elixir
{:phoenix_haml, "~> 0.1.0"}
```

and add the `PhoenixHaml.Engine` to your `config/config.exs`

```elixir
config :phoenix, :template_engines,
  haml: PhoenixHaml.Engine
```

To configure other third-party Phoenix template engines, add the extension and module to your Mix Config, ie:

```elixir
config :phoenix, :template_engines,
  slim: Slim.PhoenixEngine
```

### PubSub

The PubSub module provides a simple publish/subscribe mechanism that can be used to facilitate messaging between components in an application. To subscribe a process to a given topic, call `subscribe/2` passing in the PID and a string to identify the topic:

```elixir
Phoenix.PubSub.subscribe self, "foo"
```

Then, to broadcast messages to all subscribers to that topic:

```elixir
Phoenix.PubSub.broadcast "foo", { :message_type, some: 1, data: 2 }
```

For example, let's look at a rudimentary logger that prints messages when a controller action is invoked:

```elixir
defmodule Logger do
  def start_link do
    sub = spawn_link &(log/0)
    Phoenix.PubSub.subscribe(sub, "logging")
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
  Phoenix.PubSub.broadcast "logging", { :action, controller: "pages", action: "index" }
  render conn, "index"
end
```

### Channels

Channels broker websocket connections and integrate with the PubSub layer for message broadcasting. You can think of channels as controllers, with two differences: they are bidirectional and the connection stays alive after a reply.

We can implement a channel by creating a module in the _channels_ directory and by using `Phoenix.Channel`:

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

A channel will use a socket underneath to send responses and receive events. As said, sockets are bidirectional, which mean you can receive events (similar to requests in your controller). You handle events with pattern matching directly on the event name and message map, for example:


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

  def event(socket, "incoming:event", message) do
    reply socket, "response:event", %{message: "Echo: " <> message.content}
    socket
  end

end
```

Note that, for added clarity, events should be prefixed with their subject and a colon (i.e. "subject:event"). Instead of `reply/3`, you may also use `broadcast/3`. In the previous case, this would publish a message to all clients who previously joined the current socket's topic.

When sending process messages directly to a socket like `send socket.pid "pong"`, the
`"pong"` message triggers the `"info"` event for _all the authorized channels_ for that socket. Instead of receiving a map like normal socket events, the `info` event receives the literal message sent to the process. Below is an example:

```elixir
def event(socket, "ping", message) do
  IO.puts "sending myself pong"
  send socket.pid, "pong"
  socket
end

def event(socket, "info", "pong") do
  IO.puts "Got pong from my own ping"
  socket
end
```

Remember that a client first has to join a topic before it can send events. On the JavaScript side, this is how it would be done (don't forget to include _/js/phoenix.js_) :

```js
var socket = new Phoenix.Socket("/ws");

socket.join("channel", "topic", {some_auth_token: "secret"}, callback);
```

First you should create a socket, which uses `/ws` route name. This route's name is for you to decide in your router :

```elixir
defmodule App.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/ws"

  channel "channel", App.MyChannel
end
```

This mounts the socket router at `/ws` and also registers the above channel as `channel`. Let's recap:

 * The mountpoint for the socket in the router (/ws) has to match the route used on the JavaScript side when creating the new socket.
 * The channel name in the router has to match the first parameter on the JavaScript call to `socket.join`
 * The name of the topic used in `def join(socket, "topic", message)` function has to match the second parameter on the JavaScript call to `socket.join`

Now that a channel exists and we have reached it, it's time to do something fun with it! The callback from the previous JavaScript example receives the channel as a parameter and uses that to either subscribe to topics or send events to the server. Here is a quick example of both :

```js
var socket = new Phoenix.Socket("/ws");

socket.join("channel", "topic", {}, function(channel) {

  channel.on("pong", function(message) {
    console.log("Got " + message + " while listening for event pong");
  });

  onSomeEvent(function() {
    channel.send("ping", {data: "json stuff"});
  });

});
```
If you wish, you can send a "join" event back to the client
```elixir
def join(socket, topic, message) do
  reply socket, "join", %{content: "joined #{topic} successfully"}
  {:ok, socket}
end
```
Which you can handle after you get the channel object.
``` javascript
channel.on("join", function(message) {
  console.log("Got " + message.content);
});
```
Similarly, you can send an explicit message when denying conection.
```elixir
def join(socket, topic, message) do
  reply socket, "error", %{reason: "failed to join #{topic}"}
  {:error, socket, :reason}
end
```
and handle that like any other event
``` javascript
channel.on("error", function(error) {
  console.log("Failed to join topic. Reason: " + error.reason);
});
```

It should be noted that join and error messages are not returned by default, as the client implicitly knows whether it has successfuly subscribed to a channel: the socket will simply not receive any messages should the connection be denied.


#### Holding state in socket connections

Ephemeral state can be stored on the socket and is available for the lifetime of the socket connection using the `assign/3` imported function. This is useful for fetching channel/topic related information a single time in `join/3` and having it available within each socket `event/3` function. Here's a basic example:

```elixir
def join(socket, topic, %{"token" => token, "user_id" => user_id) do
  if user = MyAuth.find_authorized_user(user_id, token) do
    socket = assign(socket, :user, user)
    {:ok, socket}
  else
    {:error, socket, :unauthorized}
  end
end

def event(socket, "new:msg", %{msg: msg}) do
  user = socket.assigns[:user]
  broadcast socket, "new:msg", %{user_id: user.id, name: user.name, msg: msg}
  socket
end
```


There are a few other things not covered in this readme that might be worth exploring :

 * By default a socket uses the ws:// protocol and the host from the current location. If you mean to use a separate router on a host other than `location.host`, be sure to specify the full path when initializing the socket, i.e. `var socket = new Phoenix.Socket("//example.com/ws")` or `var socket = new Phoenix.Socket("ws://example.com/ws")`
 * Both the client and server side allow for leave events (as opposed to join)
 * In JavaScript, you may manually `.trigger()` events which can be useful for testing


### Configuration

Phoenix provides a configuration per environment set by the `MIX_ENV` environment variable. The default environment `dev` will be set if `MIX_ENV` does not exist.

#### Configuration file structure

```
├── my_app/config/
│   ├── config.exs          Base application configuration
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
```

#### Configuration for SSL

To launch your application with support for SSL, just place your keyfile and
certfile in the `priv` directory and configure your router with the following
options:

```elixir
# my_app/config/prod.exs
use Mix.Config

config :phoenix, MyApp.Router,
  https: [port: 443,
          host: "example.com",
          keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
          certfile: System.get_env("SOME_APP_SSL_CERT_PATH")],
  ...
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

#### Serving Your Application Behind a Proxy

If you are serving your application behind a proxy such as `nginx` or
`apache`, you will want to specify the `port` option within the `url` configuration. This will ensure
the route helper functions will use the proxy port number.

Example:

```elixir
# my_app/config/prod.exs
use Mix.Config

config :phoenix, MyApp.Router,
  ...
  http: [host: ..., port: 4000],
  url:  [host: "myurlhost", port: 80]
  ...
```

#### Configuration for Sessions

Phoenix supports a session cookie store that can be easily configured. Just
add the following configuration settings to your application's config module:

```elixir
# my_app/config/prod.exs
use Mix.Config

config :phoenix, MyApp.Router,
  ...
  secret_key_base: "..."

config :phoenix, MyApp.Router,
  session: [store: :cookie,
            key: "_your_app_key"]
```

Then you can access session data from your application's controllers.
NOTE: that `:key` and `:secret` are required options.

Example:

```elixir
defmodule MyApp.PageController do
  use Phoenix.Controller

  def show(conn, _params) do
    conn = put_session(conn, :foo, "bar")
    foo = get_session(conn, :foo)

    text conn, foo
  end
end
```


### Custom Not Found and Error Pages

Phoenix will by default render pages when a failure happens in your application using the `MyApp.ErrorView` view in your application. Additionally, `debug_errors` can be set to true if you desire a debugging error page:

  * debug_errors - Bool to display a debugging page on failures. Default `false`.
  * render_errors - The view to render error pages on failures. Default `MyApp.ErrorView`.

Everytime there is a failure and debugging is disable, the `render/2` will be invoked in the view with the template name according to its status and format, for example, "404.html" or "500.json". See `MyApp.ErrorView` generated in your application for code samples on how to customize your error pages.

#### Plug.Exception

Phoenix uses the `Plug.Exception` protocol when rendering error pages to figure out which status code an exception should be rendered with. For example, `Phoenix.Router.NoRouteError` uses this protocol to set its status code to 404.

There are two ways of setting the status code of an exception. If you are defining the exception in your application and the exception belongs to the HTTP layer, you can directly define a `plug_status` field:

```elixir
defmodule Phoenix.Route.NoRouteError do
  defexception plug_status: 404, message: "no route found"
end
```

However, if you want to extend an existing exception with Plug.Exception, you just need to directly implement the protocol. For example, if you are using Ecto, you may want to define the following:

```elixir
defimpl Plug.Exception, for: Ecto.NotSingleResult do
  def status(_exception), do: 404
end
```

### Mix Tasks

```console
mix phoenix.new     app_name destination_path  # Creates new Phoenix application
mix phoenix.routes  [MyApp.Router]             # Prints routes
mix phoenix.server   [MyApp.Router]            # Starts the server
mix phoenix --help                             # This help
```

### Static Assets

Static assets are enabled by default and served from the `priv/static/`
directory of your application. The assets are mounted at the root path, so
`priv/static/js/phoenix.js` would be served from `example.com/js/phoenix.js`.
See configuration options for details on disabling assets and customizing the
mount point.


## Documentation

API documentation is available at [http://hexdocs.pm/phoenix](http://hexdocs.pm/phoenix)


## Development

There are no guidelines yet. Do what feels natural. Submit a bug, join a discussion, open a pull request.

### Building phoenix.coffee

```bash
$ coffee -o priv/static/js -cw assets/cs
```

## Contributing

We appreciate any contribution to Phoenix, so check out our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more information. We usually keep a list of features and bugs [in the issue tracker][1].

## Important links

* \#elixir-lang on freenode IRC
* [Issue tracker][1]
* [phoenix-talk Mailing list (questions)][2]
* [phoenix-core Mailing list (development)][3]

  [1]: https://github.com/phoenixframework/phoenix/issues
  [2]: http://groups.google.com/group/phoenix-talk
  [3]: http://groups.google.com/group/phoenix-core


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
  - [x] Enviroment Based logging with log levels with Elixir's Logger
  - [x] Static File serving
- Controllers
  - [x] html/json/text helpers
  - [x] redirects
  - [x] Plug layer for action hooks
  - [x] Error page handling
  - [x] Error page handling per env
- Views
  - [x] Precompiled View handling
  - [x] I18n
- Realtime
  - [x] Websocket multiplexing/channels
  - [x] Browser js client
  - [ ] iOS client (WIP)
  - [ ] Android client
