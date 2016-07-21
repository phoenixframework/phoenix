In order to serve an application behind a proxy webserver such as `nginx` or `apache`, we will need to configure a specific port for our application to listen on.

There are two ways we can approach this. If we are sure that we can pick a port number which will not need to change, we can hard-code it as `http: [port: 8080]` line of our `config/prod.exs` file.

```elixir
use Mix.Config

. . .

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: 8080],
  cache_static_manifest: "priv/static/manifest.json"

. . .
```

If we need our port configuration to be flexible, perhaps even change for every host we deploy to, we can get the port value from an existing environment value set on the system. Again, here is our `config/prod.exs` file.

```elixir
use Mix.Config

. . .

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/manifest.json"

. . .
```

Urls generated using a `_url` function from the `HelloPhoenix.Router.Helpers` module will include a url such as http://localhost:8080/users for `user_url(conn, :index)`. To fix this we can use the `url` option:

```elixir
use Mix.Config

. . .

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: 8080],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/manifest.json"

. . .
```

Our url will now be http://example.com/users for the `user_url(conn, :index)` function. Note that the port is not present in the url. If the scheme is `http` and the port is `80`, or the scheme is `https` and the port is `443`, then the port will not be present in the url. In all other circumstances it will be present.

### Nginx Considerations
Nginx requires some additional configuration in order to use channels. Websockets, which are based on HTTP requests, operate on the notion that you are _Upgrading_ the connection from standard stateless HTTP to a persistent websocket connection.

Thankfully, this is relatively straightforward to accomplish with nginx.

Below is a standard `sites-enabled` style nginx configuration, for a given domain `my-app.domain`.

```
// /etc/nginx/sites-enabled/my-app.domain
upstream phoenix {
  server 127.0.0.1:4000 max_fails=5 fail_timeout=60s;
}

server {
  server_name my-app.domain;
  listen 80;

  location / {
    allow all;

    # Proxy Headers
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Cluster-Client-Ip $remote_addr;

    # The Important Websocket Bits!
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://phoenix;
  }
}

```
This configures two objects - the proxy endpoint, defined as an `upstream`, as well as a `server`, which is configured to listen under a specific domain name and port.

The `server` is the primary concern here. With this configuration, you have ensured that the correct headers are passed down to the Phoenix process for channels to work, through the `Upgrade` and `Connection` headers.

These headers do not immediately turn on websockets, you're still responsible for that in your javascript code, the headers simply allow for the correct capabilities to be passed to Phoenix from the browser.
