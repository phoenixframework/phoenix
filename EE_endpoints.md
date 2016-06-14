### Introduction
Each request comes in through an endpoint. Endpoints handle the request up to the
point of passing it off the a [Router](http://www.phoenixframework.org/docs/routing).

Each request begins and ends it's lifecycle inside your application in an endpoint.

The sample [Hello
Phoenix](https://github.com/phoenix-examples/hello_phoenix) Phoenix application starts up our HelloPhoenix.Endpoint as a supervised process.
This is where Supervision from Erlang and Elixir enter this framework.

Below is from
[`lib/hello_phoenix.ex`](https://github.com/phoenix-examples/hello_phoenix/blob/master/lib/hello_phoenix.ex#L9-L16):
```elixir
 # ...
 children = [¬
   # Start the endpoint when the application starts¬
   supervisor(HelloPhoenix.Endpoint, []),¬
   # ... Other supervised processes like Ecto Repo or
   # worker processes
   supervisor(HelloPhoenix.Repo, []),
   supervisor(HelloPhoenix.QueueWorker, [])
  ]
  # ...
```

These lines declare that our application is composed of multiple process trees.

### Endpoint Contents
An endpoint often includes plugs that are useful throughout all routes of
your application. At the end of an endpoint file we can define multiple routers that would
handle the actual routes.

Let's cover some of the elements of an Endpoint layer by layer from outside
moving inward by looking at the endpoint.ex in the [Hello
Phoenix](https://github.com/phoenix-examples/hello_phoenix) sample Phoenix
application.

An `Endpoint` is an Elixir module like the `Controller` and `Router`.

```elixir
defmodule HelloPhoenix.Endpoint do¬
  ...
end
```
Frequently the first directive inside of our Endpoint module will be an inclusion
of the Phoenix.Endpoint and a declaration that this is an otp_app. [This
code](https://github.com/phoenixframework/phoenix/blob/e118c485a1a0bdc1f4f2fe199f980b5fff691376/lib/phoenix/endpoint.ex#L362-L369) is
executed when the below `use` line is executed. This declares that this is an
otp_app called "hello_phoenix" which is enough for the OTP configuration to get
started and [start the endpoint supervision
tree](https://github.com/phoenixframework/phoenix/blob/e118c485a1a0bdc1f4f2fe199f980b5fff691376/lib/phoenix/endpoint.ex#L467)
```elixir
  use Phoenix.Endpoint, otp_app: :hello_phoenix
```
Next the endpoint declares a socket on the /socket URI. /socket requests will be handled by the
HelloPhoenix.UserSocket module which is declared elsewhere in our application.
Here we are just declaring that such a connection will exist.

```elixir
  socket "/socket", HelloPhoenix.UserSocket
```
Next a series of plugs which would have to relevant to every route in your application.
You may want to customize some of the features, enabling gzip:true when deploying to production
with digested static files.

Static files are served from priv/static before any part of our request makes it to a router.

```elixir
  plug Plug.Static,¬
    at: "/", from: :hello_phoenix, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
```
A code reloading feature is included into our application which uses a socket
to communicate that code can be reloaded for development preview.

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end
```
The next section defines a list of separate applications that perform useful
operations on our request. A logger is enabled. A request ID is generated.

```elixir
  plug Plug.RequestId¬
  plug Plug.Logger
```

For example a session cookie is created and signed to ensure request security
and prevent XSS.

```elixir
  plug Plug.Session,
    store: :cookie,
    key: "_hello_phoenix_key",
    signing_salt: "change_me"
```
Finally by convention the router for our application is included where the request
will be routed to the appropriate place within your code.

```elixir
  plug HelloPhoenix.Router
```

In these succinct lines all of the common functionality among our HTTP requests
for our application is defined and can be further customized for our application
endpoint.

### Endpoint Uses

Endpoints gather together common functionality and serve as entrance and exit
for all of the HTTP requests to your application.

One thing to note up above is that our HelloPhoenix application may
come with multiple endpoints creating an integrated but separated process tree
for major pieces of our application. The main routes are one process tree and
there may be uses for other independent process trees in an application that shares
context but wants separation of fault tolerance and different characteristics.
This allows an administrative portion of your application to not only be a
separate route but be an entire logically different endpoint from the main
application.

Faults in the admin or the Ecto repository will not immediately impact the main
application allowing the gen server to restart those processes separately after
unexpected faults.

Read the complete [Endpoint
API](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html) on hexdocs.
