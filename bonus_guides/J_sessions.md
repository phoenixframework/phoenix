Phoenix gets its session functionality from Plug. Plug ships with two forms of session storage out of the box - cookies, and Erlang Term Storage (ETS).

## Cookies

Phoenix uses Plug's cookie session storage by default. The two things that make this work are having a `secret_key_base` configured for our environment - this includes the base `config/config.exs` - and the correct configuration for `Plug.Session` in our endpoint.

Here's the `config/config.exs` file from a newly generated Phoenix application, showing the `secret_key_base` set for us.

```elixir
config :hello_phoenix, HelloPhoenix.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "some_crazy_long_string_phoenix_generated",
  debug_errors: false,
  pubsub: [name: HelloPhoenix.PubSub,
  adapter: Phoenix.PubSub.PG2]
```

Plug uses our `secret_key_base` value to encrypt and sign each cookie to make sure it can't be read or tampered with.

And here is the default `Plug.Session` configuration from `lib/hello_phoenix/endpoint.ex`.

```elixir
defmodule HelloPhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello_phoenix
. . .
  plug Plug.Session,
    store: :cookie,
    key: "_hello_phoenix_key",
    signing_salt: "Jk7pxAMf"
. . .
end
```

## ETS
Phoenix also supports server-side sessions via ETS. To configure ETS sessions, we need to create an ETS table when we start our application. We'll call ours `session`. We also need to re-configure `Plug.Session` in our endpoint.

Here's how we would create an ETS table on application startup in `lib/hello_phoenix.ex`.

```elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false
  :ets.new(:session, [:named_table, :public, read_concurrency: true])
. . .
```

In order to re-configure `Plug.Session`, we need to change the store, specify the name of the key for the ETS table, and specify the name of the table in which we are storing the sessions. The `secret_key_base` is not necessary if we are using ETS session storage.

Here is how it looks in `lib/hello_phoenix/endpoint.ex`.

```elixir
defmodule HelloPhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello_phoenix
  . . .
  plug Plug.Session,
    store: :ets,
    key: "sid",
    table: :session,
  . . .
end
```

While we can use ETS for session storage, it might not be the best idea. This is from the `Plug.Session` documentation.

> We don’t recommend using this store in production as every session will be stored in ETS and never cleaned until you create a task responsible for cleaning up old entries.

> Also, since the store is in-memory, it means sessions are not shared between servers. If you deploy to more than one machine, using this store is again not recommended.

## Accessing Session Data

With the proper configuration in place, we can access session data in our application's controllers.

Here's a really quick example of putting a value into the session and getting it out again. We can change the `index` action of our generated `HelloPhoenix.PageController` at `web/controllers/page_controller.ex` to use `put_session/2`, `get_session/2`, and then render only the text that made the session round-trip.

```elixir
defmodule HelloPhoenix.PageController do
  use HelloPhoenix.Web, :controller

  def index(conn, _params) do
    conn = put_session(conn, :message, "new stuff we just set in the session")
    message = get_session(conn, :message)

    text conn, message
  end
end
```
