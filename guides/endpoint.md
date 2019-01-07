# Endpoint

Phoenix applications start the HelloWeb.Endpoint as a supervised process. By default, the Endpoint is added to the supervision tree in `lib/hello/application.ex` as a supervised process. Each request begins and ends its lifecycle inside your application in an endpoint. The endpoint handles starting the web server and transforming requests through several defined plugs before calling the [Router](routing.html).


```elixir
defmodule Hello.Application do
  use Application
  def start(_type, _args) do
    ...

    children = [
      HelloWeb.Endpoint
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
socket "/socket", HelloWeb.UserSocket,
  websocket: true,
  longpoll: false
```

Next comes a series of plugs that are relevant to all requests in our application. We can customize some of the features, for example, enabling `gzip: true` when deploying to production to gzip the static files.

Static files are served from `priv/static` before any part of our request makes it to a router.

```elixir
plug Plug.Static,
  at: "/",
  from: :hello,
  gzip: false,
  only: ~w(css fonts images js favicon.ico robots.txt)
```
If code reloading is enabled, a socket will be used to communicate to the browser that the page needs to be reloaded when code is changed on the server. This feature is enabled by default in the development environment. This is configured using `config :hello, HelloWeb.Endpoint, code_reloader: true`.

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

Faults in the different parts of the supervision tree, such as the Ecto Repo, will not immediately impact the main application. The supervisor is therefore able to restart those processes separately after unexpected faults. It is also possible for an application to have multiple endpoints, each with its own supervision tree.

There are many functions defined in the endpoint module for path helpers, channel subscriptions and broadcasts, instrumentation, and endpoint configuration. These are all covered in the [Endpoint API docs](Phoenix.Endpoint.html#module-endpoint-api) for `Phoenix.Endpoint`.


## Using SSL

To prepare an application to serve requests over SSL, we need to add a little bit of configuration and two environment variables. In order for SSL to actually work, we'll need a key file and certificate file from a certificate authority. The environment variables that we'll need are paths to those two files.

The configuration consists of a new `https:` key for our endpoint whose value is a keyword list of port, path to the key file, and path to the cert (pem) file. If we add the `otp_app:` key whose value is the name of our application, Plug will begin to look for them at the root of our application. We can then put those files in our `priv` directory and set the paths to `priv/our_keyfile.key` and `priv/our_cert.crt`.

Here's an example configuration from `config/prod.exs`.

```elixir
use Mix.Config

config :hello, HelloWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  https: [
    port: 443,
    otp_app: :hello,
    keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
    certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),
    # OPTIONAL Key for intermediate certificates:
    cacertfile: System.get_env("INTERMEDIATE_CERTFILE_PATH")
  ]

```

Without the `otp_app:` key, we need to provide absolute paths to the files wherever they are on the filesystem in order for Plug to find them.

```elixir
Path.expand("../../../some/path/to/ssl/key.pem", __DIR__)
```

If you require further customization to the TLS versions or ciphers used you can include additional `https:` configuration. For example to disable older versions of TLS which are now considered insecure you could add `versions: [:'tlsv1.2']`. More information on the available settings is available in the [Erlang SSL docs](http://erlang.org/doc/man/ssl.html) (see "TLS/DTLS OPTION DESCRIPTIONS - SERVER SIDE").


### SSL in Development

If you would like to use HTTPS in development, a self-signed certificate can be generated by running: `mix phx.gen.cert`. This requires Erlang/OTP 20 or later.

With your self-signed certificate, your development configuration in `config/dev.exs` can be updated to run an HTTPS endpoint:

```elixir
config :my_app, MyApp.Endpoint,
  ...
  https: [
    port: 4001,
    cipher_suite: :strong,
    keyfile: "priv/cert/selfsigned_key.pem",
    certfile: "priv/cert/selfsigned.pem"
  ]
```

This can replace your `http` configuration, or you can run HTTP and HTTPS servers on different ports.

### Force SSL

In many cases, you'll want to force all incoming requests to use SSL by redirecting HTTP to HTTPS. This can be accomplished by setting the `:force_ssl` option in your endpoint configuration. It expects a list of options which are forwarded to `Plug.SSL`. By default it sets the "strict-transport-security" header in HTTPS requests, forcing browsers to always use HTTPS. If an unsafe (HTTP) request is sent, it redirects to the HTTPS version using the `:host` specified in the `:url` configuration. For example:

```elixir
config :my_app, MyApp.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]]
```

To dynamically redirect to the `host` of the current request, set `:host` in the `:force_ssl` configuration to `nil`.

```elixir
config :my_app, MyApp.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto], host: nil]
```

### HSTS

HSTS or "strict-transport-security" is a mechanism that allows a website to declare itself as only accessible via a secure connection (HTTPS). It was introduced to prevent man-in-the-middle attacks that strip SSL/TLS. It causes web browers to redirect from HTTP to HTTPS and refuse to connect unless the connection uses SSL/TLS.

With `force_ssl: :hsts` set the `Strict-Transport-Security` header is set with a max age that defines the length of time the policy is valid for. Modern web browsers will respond to this by redirecting from HTTP to HTTPS for the standard case but it does have other consequenses. [RFC6797](https://tools.ietf.org/html/rfc6797) which defines HSTS also specifies **that the browser should keep track of the policy of a host and apply it until it expires.** It also specifies that **traffic on any port other than 80 is assumed to be encrypted** as per the policy.

This can result in unexpected behaviour if you access your application on localhost, for example `https://localhost:4000`, as from that point forward and traffic coming from localhost will be expected to be encrypted, except port 80 which will be redirected to port 443. This has the potential to disrupt traffic to any other local servers or proxies that you may be running on your computer. Other applications or proxies on localhost will refuse to work unless the traffic is encrypted.

If you do inadvertently turn on HSTS for localhost you may need to reset the cache on your browser before it will accept any HTTP traffic from localhost. For Chrome you need to `Empty Cache and Hard Reload` which is available from the reload menu that appears when you click and hold the reload icon from the Developer Tools Panel. For Safari you will need to clear your cache, remove the entry from `~/Library/Cookies/HSTS.plist` (or delete that file entirely) and restart Safari. Alternately you can set the `:expires` option on `force_ssl` to `0` which should expired the entry to turn off HSTS. More information on the options for HSTS are available at [Plug.SSL](https://hexdocs.pm/plug/Plug.SSL.html).
