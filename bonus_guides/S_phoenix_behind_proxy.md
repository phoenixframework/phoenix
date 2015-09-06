In order to serve an application behind a proxy webserver such as `nginx` or `apache`, we will need to configure a specific port for our application to listen on. This will ensure the url helper functions will use the correct proxy port number.

There are two ways we can approach this. If we are sure that we can pick a port number which will not need to change, we can hard-code it as `http: [port: 8080]` line of our `config/prod.exs` file.

```elixir
use Mix.Config

. . .

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: 8080],
  url: [host: "example.com"],
  cache_static_manifest: "priv/static/manifest.json"

. . .
```

If we need our port configuration to be flexible, perhaps even change for every host we deploy to, we can get the port value from an existing environment value set on the system. Again, here is our `config/prod.exs` file.

```elixir
use Mix.Config

. . .

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com"],
  cache_static_manifest: "priv/static/manifest.json"

. . .
```
