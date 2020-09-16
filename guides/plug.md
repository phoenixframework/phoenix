# Plug

> **Requirement**: This guide expects that you have gone through the introductory guides and got a Phoenix application up and running.

> **Requirement**: This guide expects that you have gone through [the Request life-cycle guide](request_lifecycle.html).

Plug lives at the heart of Phoenix's HTTP layer, and Phoenix puts Plug front and center. We interact with plugs at every step of the request life-cycle, and the core Phoenix components like Endpoints, Routers, and Controllers are all just Plugs internally. Let's jump in and find out just what makes Plug so special.

[Plug](https://github.com/elixir-lang/plug) is a specification for composable modules in between web applications. It is also an abstraction layer for connection adapters of different web servers. The basic idea of Plug is to unify the concept of a "connection" that we operate on. This differs from other HTTP middleware layers such as Rack, where the request and response are separated in the middleware stack.

At the simplest level, the Plug specification comes in two flavors: *function plugs* and *module plugs*.

## Function Plugs

In order to act as a Plug, a function needs to accept a connection struct (`%Plug.Conn{}`) and options. It also needs to return a connection struct. Any function that meets those criteria will do. Here's an example.

```elixir
def introspect(conn, _opts) do
  IO.puts """
  Verb: #{inspect(conn.method)}
  Host: #{inspect(conn.host)}
  Headers: #{inspect(conn.req_headers)}
  """

  conn
end
```

This function does the following:

  1. It receives a connection and options (that we do not use)
  2. It prints some connection information to the terminal
  3. It returns the connection

Pretty simple, right? Let's see this function in action by adding it to our endpoint in `lib/hello_web/endpoint.ex`. We can plug it anywhere, so let's do it before we delegate the request to the router:

```elixir
defmodule HelloWeb.Endpoint do
  ...

  plug :introspect
  plug HelloWeb.Router

  def introspect(conn, _opts) do
    IO.puts """
    Verb: #{inspect(conn.method)}
    Host: #{inspect(conn.host)}
    Headers: #{inspect(conn.req_headers)}
    """

    conn
  end
end
```

Function plugs are plugged by passing the function name as an atom. To try the Plug out, go back to your browser and fetch "http://localhost:4000". You should see something like this printed in your terminal:

```console
Verb: "GET"
Host: "localhost"
Headers: [...]
```

Our Plug simply prints information from the connection. Although our initial Plug is very simple, you can virtually do anything you want inside of it. To learn about all fields available in the connection and all of the functionality associated to it, [see the documentation for Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html).

Now let's look at the other flavor plugs come in, module plugs.

## Module Plugs

Module plugs are another type of Plug that let us define a connection transformation in a module. The module only needs to implement two functions:

- `init/1` which initializes any arguments or options to be passed to `call/2`
- `call/2` which carries out the connection transformation. `call/2` is just a function plug that we saw earlier

To see this in action, let's write a module plug that puts the `:locale` key and value into the connection assign for downstream use in other plugs, controller actions, and our views. Put the contents above to a file named "lib/hello_web/plugs/locale.ex":

```elixir
defmodule HelloWeb.Plugs.Locale do
  import Plug.Conn

  @locales ["en", "fr", "de"]

  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}} = conn, _default) when loc in @locales do
    assign(conn, :locale, loc)
  end

  def call(conn, default) do
    assign(conn, :locale, default)
  end
end
```

To give it a try, let's add this plug to our router:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWeb.Plugs.Locale, "en"
  end
  ...
```

We are able to add this module plug to our browser pipeline via `plug HelloWeb.Plugs.Locale, "en"`. In the `init/1` callback, we pass a default locale to use if none is present in the params. We also use pattern matching to define multiple `call/2` function heads to validate the locale in the params, and fall back to "en" if there is no match.

To see the assign in action, go to the layout in "lib/hello_web/templates/layout/app.html.eex" and add the following close to the main container:

```html
<main role="main" class="container">
  <p>Locale: <%= @locale %></p>
```

Go to "http://localhost:4000/" and you should see the locale exhibited. Visit "http://localhost:4000/?locale=fr" and you should see the assign changed to "fr". Someone can use this information alongside [Gettext](https://hexdocs.pm/gettext/Gettext.html) to provide a fully internationalized web application.

That's all there is to Plug. Phoenix embraces the plug design of composable transformations all the way up and down the stack. Let's see some examples!

## Where to plug

The endpoint, router, and controllers in Phoenix accept plugs.

### Endpoint plugs

Endpoints organize all the plugs common to every request, and apply them before dispatching into the router with its custom pipelines. We added a plug to the endpoint like this:

```elixir
defmodule HelloWeb.Endpoint do
  ...

  plug :introspect
  plug HelloWeb.Router
```

The default Endpoint plugs do quite a lot of work. Here they are in order:

- [Plug.Static](https://hexdocs.pm/plug/Plug.Static.html) - serves static assets. Since this plug comes before the logger, serving of static assets is not logged

- [Phoenix.CodeReloader](https://hexdocs.pm/phoenix/Phoenix.CodeReloader.html) - a plug that enables code reloading for all entries in the web directory. It is configured directly in the Phoenix application

- [Plug.RequestId](https://hexdocs.pm/plug/Plug.RequestId.html) - generates a unique request id for each request.

- [Plug.Telemetry](https://hexdocs.pm/plug/Plug.Telemetry.html) - adds instrumentation points so Phoenix can log the request path, status code and request time by default.

- [Plug.Parsers](https://hexdocs.pm/plug/Plug.Parsers.html) - parses the request body when a known parser is available. By default parsers parse urlencoded, multipart and json (with `jason`). The request body is left untouched when the request content-type cannot be parsed

- [Plug.MethodOverride](https://hexdocs.pm/plug/Plug.MethodOverride.html) - converts the request method to PUT, PATCH or DELETE for POST requests with a valid `_method` parameter

- [Plug.Head](https://hexdocs.pm/plug/Plug.Head.html) - converts HEAD requests to GET requests and strips the response body

- [Plug.Session](https://hexdocs.pm/plug/Plug.Session.html) - a plug that sets up session management. Note that `fetch_session/2` must still be explicitly called before using the session as this Plug just sets up how the session is fetched

In the middle of the endpoint, there is also a conditional block:

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :demo
  end
```

This block is only executed in development. It enables live reloading (if you change a CSS file, they are updated in-browser without refreshing the page), code reloading (so we can see changes to our application without restarting the server), and check repo status (which makes sure our database is up to date, raising readable and actionable error otherwise).

### Router plugs

In the router, we can declare plugs inside pipelines:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWeb.Plugs.Locale, "en"
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
  end
```

Routes are defined inside scopes and scopes may pipe through multiple pipelines. Once a route matches, Phoenix invokes all plugs defined in all pipelines associated to that route. For example, accessing "/" will pipe through the `:browser` pipeline, consequently invoking all of its plugs.

As we will see in [the Routing guide](routing.html), the pipelines themselves are plugs. There we will also discuss all plugs in the `:browser` pipeline.

### Controller plugs

Finally, controllers are plugs too, so we can do:

```elixir
defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  plug HelloWeb.Plugs.Locale, "en"
```

In particular, controller plugs provide a feature that allows us to execute plugs only within certain actions. For example, you can do:

```elixir
defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  plug HelloWeb.Plugs.Locale, "en" when action in [:index]
```

And the plug will only be executed for the `index` action.

## Plugs as composition

By abiding by the plug contract, we turn an application request into a series of explicit transformations. It doesn't stop there. To really see how effective Plug's design is, let's imagine a scenario where we need to check a series of conditions and then either redirect or halt if a condition fails. Without plug, we would end up with something like this:

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  def show(conn, params) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        case find_message(params["id"]) do
          nil ->
            conn |> put_flash(:info, "That message wasn't found") |> redirect(to: "/")
          message ->
            if Authorizer.can_access?(user, message) do
              render(conn, :show, page: message)
            else
              conn |> put_flash(:info, "You can't access that page") |> redirect(to: "/")
            end
        end
      :error ->
        conn |> put_flash(:info, "You must be logged in") |> redirect(to: "/")
    end
  end
end
```

Notice how just a few steps of authentication and authorization require complicated nesting and duplication? Let's improve this with a couple of plugs.

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  plug :authenticate
  plug :fetch_message
  plug :authorize_message

  def show(conn, params) do
    render(conn, :show, page: conn.assigns[:message])
  end

  defp authenticate(conn, _) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        assign(conn, :user, user)
      :error ->
        conn |> put_flash(:info, "You must be logged in") |> redirect(to: "/") |> halt()
    end
  end

  defp fetch_message(conn, _) do
    case find_message(conn.params["id"]) do
      nil ->
        conn |> put_flash(:info, "That message wasn't found") |> redirect(to: "/") |> halt()
      message ->
        assign(conn, :message, message)
    end
  end

  defp authorize_message(conn, _) do
    if Authorizer.can_access?(conn.assigns[:user], conn.assigns[:message]) do
      conn
    else
      conn |> put_flash(:info, "You can't access that page") |> redirect(to: "/") |> halt()
    end
  end
end
```

To make this all work, we converted the nested blocks of code and used `halt(conn)` whenever we reached a failure path. The `halt(conn)` functionality is essential here: it tells Plug that the next plug should not be invoked.

At the end of the day, by replacing the nested blocks of code with a flattened series of plug transformations, we are able to achieve the same functionality in a much more composable, clear, and reusable way.

To learn more about Plugs, see the documentation for [the Plug project](https://hexdocs.pm/plug), which provides many built-in plugs and functionalities.
