# Endpoint

Phoenix applications start the HelloWeb.Endpoint as a supervised process. By default, the Endpoint is added to the supervision tree in `lib/hello/application.ex` as a supervised process. Each request begins and ends its lifecycle inside your application in an endpoint. The endpoint handles starting the web server and transforming requests through several defined plugs before calling the [Router](routing.html).


```elixir
defmodule Hello.Application do
  use Application
  def start(_type, _args) do
    #...

    children = [
      supervisor(HelloWeb.Endpoint, []),
    ]

    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Endpoint Contents

Endpoints gather together common functionality and serve as entrance and exit for all of the HTTP requests to your application. The endpoint holds plugs that are common to all requests coming into your application.

Let's take a look at the endpoint for the application `Hello` generated in the [Up and Running](up_and_running.html) page.

```elixir
defmodule HelloWeb.Endpoint do
  ...
end
```
The first call inside of our Endpoint module is the `use Phoenix.Endpoint` macro with the `otp_app`. The `otp_app` is used for the configuration. This defines several functions on the `HelloWeb.Endpoint` module, including the `start_link` function which is called in the supervision tree.

```elixir
  use Phoenix.Endpoint, otp_app: :hello
```

Next the endpoint declares a socket on the "/socket" URI. "/socket" requests will be handled by the `HelloWeb.UserSocket` module which is declared elsewhere in our application. Here we are just declaring that such a connection will exist.

```elixir
  socket "/socket", HelloWeb.UserSocket
```

Next comes a series of plugs that are relevant to all requests in our application. We can customize some of the features, for example, enabling `gzip: true` when deploying to production to gzip the static files.

Static files are served from `priv/static` before any part of our request makes it to a router.

```elixir
  plug Plug.Static,
    at: "/", from: :hello, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
```
If code reloading is enabled, a socket will be used to communicate to the browser that the page needs to be reloaded when code is changed on the server. This feature is enabled by default in the development environment. This is configured using `config :hello, HelloWeb.Endpoint, core_reloader: true`.

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end
```

[Plug.RequestId](https://hexdocs.pm/plug/Plug.RequestId.html) generates a unique id for each request and [Plug.Logger](https://hexdocs.pm/plug/Plug.Logger.html) logs the request path, status code and request time by default.

```elixir
  plug Plug.RequestId
  plug Plug.Logger
```

[Plug.Session](https://hexdocs.pm/plug/Plug.Session.html) handles the session cookies and session stores.

```elixir
  plug Plug.Session,
    store: :cookie,
    key: "_hello_key",
    signing_salt: "change_me"
```

By default the last plug in the endpoint is the router. The router matches a path to a particular controller action or plug. The router is covered in the [Routing Guide](routing.html).

```elixir
  plug HelloWeb.Router
```

The endpoint can be customized to add additional plugs, to allow HTTP basic authentication, CORS, subdomain routing and more.

The final thing generated in the endpoint by default is the `init` function. This callback is used for dynamic configuration. The specifics of the dynamic configuration are covered in the `Phoenix.Endpoint` module documentation.

```elixir
def init(_key, config) do
  if config[:load_from_system_env] do
    port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
    {:ok, Keyword.put(config, :http, [:inet6, port: port])}
  else
    {:ok, config}
  end
end
```

Faults in the different parts of the supervision tree, such as the Ecto Repo, will not immediately impact the main application. The supervisor is therefore able to restart those processes separately after unexpected faults. It is also possible for an application to have multiple endpoints, each with its own supervision tree.

There are many functions defined in the endpoint module for path helpers, channel subscriptions and broadcasts, instrumentation, and endpoint configuration. These are all covered in the [Endpoint API of the `Phoenix.Endpoint` docs](Phoenix.Endpoint.html#module-endpoints-api).
