![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/images/phoenix.png)
> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

### Requirements

- Elixir v1.0.0+

### Setup

1. Install Phoenix

        git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && git checkout v0.5.0 && mix do deps.get, compile


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

  scope alias: YourApp do
    get "/pages/:page", PageController, :show, as: :pages
    get "/files/*path", FileController, :show

    resources "/users", UserController do
      resources "/comments", CommentController
    end
  end

  scope path: "/admin", alias: YourApp.Admin, helper: "admin" do
    resources "/users", UserController
  end
end
```

Routes specified using `get`, `post`, `put`, and `delete` respond to the corresponding HTTP method. The second and third parameters are the controller module and function, respectively. For example, the line `get "/files/*path", FileController, :show` above will route GET requests matching `/files/*path` to the `FileController.show` function.

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
put  "/users/:id",      UserController, :update
patch "/users/:id",     UserController, :update
delete "/users/:id",    UserController, :destroy
```

Resources will also generate a set of named routes and associated helper methods:

```elixir
defmodule YourApp.Router do
  use Phoenix.Router

  resources "/users", UserController do
    resources "/comments", CommentController
  end
end

iex> YourApp.Router.Helpers.user_path(:index)
"/users"

iex> YourApp.Router.Helpers.user_path(:show, 123)
"/users/123"

iex> YourApp.Router.Helpers.user_path(:show, 123, page: 5)
"/users/123?page=5"

iex> YourApp.Router.Helpers.user_path(:edit, 123)
"/users/123/edit"

iex> YourApp.Router.Helpers.user_path(:destroy, 123)
"/users/123"

iex> YourApp.Router.Helpers.user_path(:new)
"/users/new"

iex> YourApp.Router.Helpers.user_comment_path(:show, 99, 100)
"/users/99/comments/100"

iex> YourApp.Router.Helpers.user_comment_path(:index, 99, foo: "bar")
"/users/99/comments?foo=bar"

iex> YourApp.Router.Helpers.user_comment_path(:index, 99) |> YourApp.Router.Helpers.url
"http://example.com/users/99/comments"

iex> YourApp.Router.Helpers.user_comment_path(:edit, 88, 2, [])
"/users/88/comments/2/edit"

iex> YourApp.Router.Helpers.user_comment_path(:new, 88)
"/users/88/comments/new"
```

#### Method Overrides

Since browsers don't allow HTML forms to send PUT or DELETE requests, Phoenix allows the POST method to be overridden, either by adding a `_method` form parameter, or specifying an `x-http-method-override` HTTP header.

For example, to make a button to delete a post, you could write:

```html
<form action="<%= post_path(:destroy, @post.id) %>" method="post">
  <input type="hidden" name="_method" value="DELETE">
  <input type="submit" value="Delete Post">
</form>
```

### Controller examples

```elixir
defmodule YourApp.PageController do
  use Phoenix.Controller
  plug :action

  def show(conn, %{"page" => "admin"}) do
    redirect conn, YourApp.Router.Helpers.page_path(:show, "unauthorized")
  end
  def show(conn, %{"page" => page}) do
    render conn, "show", title: "Showing page #{page}"
  end
end
```

```elixir
defmodule YourApp.UserController do
  use Phoenix.Controller

  plug :action

  def show(conn, %{"id" => id}) do
    text conn, "Showing user #{id}"
  end

  def index(conn, _params) do
    json conn, JSON.encode!(Repo.all(User))
  end
end
```

### Views & Templates

Put simply, Phoenix Views *render* templates. Views also serve as a presentation layer for their templates where functions, alias, imports, etc are in context.

### Flash Examples

You could use `Phoenix.Controller.Flash` to persist messages across redirects like below.

```elixir
defmodule YourApp.PageController do
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
 * `templates` is your configured templates directory. See `web/views.ex`
 * `page` is your controller name
 * `html` is the requested format (more on that later)
 * `eex` is the default renderer
 * `application.html` is the layout because `application` is the default layout name and html is the requested format (more on that later)

Every keyword passed to `render` in the controller is available as an assign within the template, so you can use `<%= @message %>` in the eex template that is rendered in the controller example.

You may also create helper functions within your views or layouts. For example, the previous controller will use `App.PageView` so you could have :

```elixir
defmodule App.Views do
  defmacro __using__(_options) do
    quote do
      use Phoenix.View
      import unquote(__MODULE__)

      # This block is expanded within all views for aliases, imports, etc
      import App.I18n
      import App.Router.Helpers
    end
  end

  # Functions defined here are available to all other views/templates
  def title, do: "Welcome to Phoenix!"
end

defmodule App.PageView do
  use App.Views
  alias Poison, as: JSON

  def display(something) do
    String.upcase(something)
  end

  def render("show.json", %{page: page}) do
    JSON.encode! %{title: page.title, url: page.url}
  end
end
```

Which would allow you to use these functions in your template : `<%= display(@message) %>`, `<%= title %>`

Note that all views extend `App.Views`, allowing you to define functions, aliases, imports, etc available in all templates. Additionally, `render/2` functions can be defined to perform rendering directly as function definitions. The arguments to `render/2` are controller action name with the response content-type mime extension.

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
  |> render "sitemap"
end
```

Note that the layout and view templates would be chosen by matching content types, ie `application.[format].eex` would be used to render `show.[format].eex`.

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
    |> render "index", message: "hello"
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
{:phoenix_haml, "~> 0.0.4"}
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

Channels broker websocket connections and integrate with the Topic PubSub layer for message broadcasting. You can think of channels as controllers, with two differences: they are bidirectional and the connection stays alive after a reply.

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

Ephemeral state can be stored on the socket and is available for the lifetime of the socket connection using the `assign/3` and `get_assign/2` imported functions. This is useful for fetching channel/topic related information a single time in `join/3` and having it available within each socket `event/3` function. Here's a basic example:

```elixir
def join(socket, topic, %{"token" => token, "user_id" => user_id) do
  if user = MyAuth.find_authorized_user(user_id, token) do
    socket = assign(:socket, :user, user)
    {:ok, socket}
  else
    {:error, socket, :unauthorized}
  end
end

def event(socket, "new:msg", %{msg: msg}) do
  user = get_assign(socket, :user)
  broadcoast socket, "new:msg", %{user_id: user.id, name: user.name, msg: msg}
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
├── your_app/config/
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
# your_app/config/prod.exs
use Mix.Config

config :phoenix, YourApp.Router,
  port: System.get_env("PORT"),
  ssl: false,
  host: "example.com",
  cookies: true,
  session_key: "_your_app_key",
  secret_key_base: "$+X2PG$PX0^88^HXB)..."

config :logger, :console,
  level: :info,
  metadata: [:request_id]
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
`apache`, you will want to specify the `proxy_port` option. This will ensure
the route helper functions will use the proxy port number.

Example:

```elixir
# your_app/config/prod.exs
use Mix.Config

config :phoenix, YourApp.Router,
  ...
  port: 4000,
  proxy_port: 443,
  ...
```

#### Configuration for Sessions

Phoenix supports a session cookie store that can be easily configured. Just
add the following configuration settings to your application's config module:

```elixir
# your_app/config/prod.exs
use Mix.Config

config :phoenix, YourApp.Router,
  ...
  cookies: true,
  session_key: "_your_app_key",
  secret_key_base: "super secret",
  ...
```

Then you can access session data from your application's controllers.
NOTE: that `:key` and `:secret` are required options.

Example:

```elixir
defmodule YourApp.PageController do
  use Phoenix.Controller

  def show(conn, _params) do
    conn = put_session(conn, :foo, "bar")
    foo = get_session(conn, :foo)

    text conn, foo
  end
end
```


### Custom Not Found and Error Pages

An `error_controller` can be configured on the Router Mix config, where two actions must be defined for custom 404 and 500 error handling. Additionally, `catch_errors` and `debug_errors` settings control how errors are caught and displayed. Router configuration options include:


* error_controller - The optional Module to have `error/2`, `not_found/2`
                     actions invoked when 400/500's status occurs.
                     Default `Phoenix.Controller.ErrorController`
* catch_errors - Bool to catch errors at the Router level. Default `true`
* debug_errors - Bool to display Phoenix's route/stacktrace debug pages for 404/500 statuses.
             Default `false`


The `error/2` action will be invoked on the page controller when a 500 status has been assigned to the connection, but a response has not been sent, as well as anytime an error is thrown or raised (provided `catch_errors: true`)

The `not_found/2` action will be invoked on the page controller when a 404 status is assigned to the conn and a response is not sent.

#### Example Custom Error handling with PageController

```elixir
# config/config.exs
config :phoenix, YourApp.Router,
  ...
  catch_errors: true,
  debug_errors: false,
  error_controller: YourApp.PageController
```

```elixir
# config/dev.exs
config :phoenix, YourApp.Router,
  ...
  debug_errors: true # Show Phoenix route/stacktrace debug pages for 404/500's
```

```elixir
defmodule YourApp.PageController do
  use Phoenix.Controller

  def not_found(conn, _) do
    text conn, 404, "The page you were looking for couldn't be found"
  end

  def error(conn, _) do
    handle_error(conn, error(conn))
  end

  defp handle_error(conn, {:error, Ecto.NotSingleResult}) do
    not_found(conn, [])
  end

  defp handle_error(conn, _any) do
    text conn, 500, "Something went wrong"
  end
end
```

#### Catching Errors at the Controller layer

Errors can be caught at the controller layer by overriding `call/2` in the controller, i.e.:

```elixir
defmodule YourApp.UserController do
  use Phoenix.Controller

  def call(conn, opts) do
    try do
      super(conn, opts)
    rescue
      Ecto.NotSingleResult -> conn |> put_status(404) |> render "user_404"
    end
  end

  def show(conn, %{"id" => id}) do
    render conn, "index", user: Repo.get!(User, id)
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

Static assets are enabled by default and served from the `priv/static/`
directory of your application. The assets are mounted at the root path, so
`priv/static/js/phoenix.js` would be served from `example.com/js/phoenix.js`.
See configuration options for details on disabling assets and customizing the
mount point.


## Documentation

API documentation is available at [http://hexdocs.pm/phoenix/0.5.0/overview.html](http://hexdocs.pm/phoenix/0.5.0/overview.html)


## Development

There are no guidelines yet. Do what feels natural. Submit a bug, join a discussion, open a pull request.

### Building phoenix.coffee

```bash
$ coffee -o priv/static/js -cw assets/cs
```


### Building documentation

1. Clone [docs repository](https://github.com/phoenixframework/docs) into `../docs`. Relative to your `phoenix` directory.
2. Run `MIX_ENV=docs mix run release_docs.exs` in `phoenix` directory.
3. Change directory to `../docs`.
4. Commit and push docs.

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
