# Plug

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Request life-cycle guide](request_lifecycle.html).

Plug lives at the heart of Phoenix's HTTP layer, and Phoenix puts Plug front and center. We interact with plugs at every step of the request life-cycle, and the core Phoenix components like endpoints, routers, and controllers are all just plugs internally. Let's jump in and find out just what makes Plug so special.

[Plug](https://github.com/elixir-lang/plug) is a specification for composable modules in between web applications. It is also an abstraction layer for connection adapters of different web servers. The basic idea of Plug is to unify the concept of a "connection" that we operate on. This differs from other HTTP middleware layers such as Rack, where the request and response are separated in the middleware stack.

At the simplest level, the Plug specification comes in two flavors: *function plugs* and *module plugs*.

## Function plugs

In order to act as a plug, a function needs to:

1. accept a connection struct (`%Plug.Conn{}`) as its first argument, and connection options as its second one;
2. return a connection struct.

Any function that meets these two criteria will do. Here's an example.

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

Pretty simple, right? Let's see this function in action by adding it to our endpoint in `lib/hello_web/endpoint.ex`. We can plug it anywhere, so let's do it by inserting `plug :introspect` right before we delegate the request to the router:

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

Function plugs are plugged by passing the function name as an atom. To try the plug out, go back to your browser and fetch [http://localhost:4000](http://localhost:4000). You should see something like this printed in your shell terminal:

```console
Verb: "GET"
Host: "localhost"
Headers: [...]
```

Our plug simply prints information from the connection. Although our initial plug is very simple, you can do virtually anything you want inside of it. To learn about all fields available in the connection and all of the functionality associated to it, see the [documentation for `Plug.Conn`](https://hexdocs.pm/plug/Plug.Conn.html).

Now let's look at the other plug variant, the module plugs.

## Module plugs

Module plugs are another type of plug that let us define a connection transformation in a module. The module only needs to implement two functions:

- [`init/1`] which initializes any arguments or options to be passed to [`call/2`]
- [`call/2`] which carries out the connection transformation. [`call/2`] is just a function plug that we saw earlier

To see this in action, let's write a module plug that puts the `:locale` key and value into the connection for downstream use in other plugs, controller actions, and our views. Put the contents below in a file named `lib/hello_web/plugs/locale.ex`:

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

To give it a try, let's add this module plug to our router, by appending `plug HelloWeb.Plugs.Locale, "en"`  to our `:browser` pipeline in `lib/hello_web/router.ex`:

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

In the [`init/1`] callback, we pass a default locale to use if none is present in the params. We also use pattern matching to define multiple [`call/2`] function heads to validate the locale in the params, and fall back to `"en"` if there is no match. The [`assign/3`] is a part of the `Plug.Conn` module and it's how we store values in the `conn` data structure.

To see the assign in action, go to the layout in `lib/hello_web/components/layouts/app.html.heex` and add the following code to the main container:

```heex
<main class="px-4 py-20 sm:px-6 lg:px-8">
  <p>Locale: <%= @locale %></p>
```

Go to [http://localhost:4000/](http://localhost:4000/) and you should see the locale exhibited. Visit [http://localhost:4000/?locale=fr](http://localhost:4000/?locale=fr) and you should see the assign changed to `"fr"`. Someone can use this information alongside [Gettext](https://hexdocs.pm/gettext/Gettext.html) to provide a fully internationalized web application.

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

The default endpoint plugs do quite a lot of work. Here they are in order:

- `Plug.Static` - serves static assets. Since this plug comes before the logger, requests for static assets are not logged.

- `Phoenix.LiveDashboard.RequestLogger` - sets up the *Request Logger* for Phoenix LiveDashboard, this will allow you to have the option to either pass a query parameter to stream requests logs or to enable/disable a cookie that streams requests logs from your dashboard.

- `Plug.RequestId` - generates a unique request ID for each request.

- `Plug.Telemetry` - adds instrumentation points so Phoenix can log the request path, status code and request time by default.

- `Plug.Parsers` - parses the request body when a known parser is available. By default, this plug can handle URL-encoded, multipart and JSON content (with `Jason`). The request body is left untouched if the request content-type cannot be parsed.

- `Plug.MethodOverride` - converts the request method to PUT, PATCH or DELETE for POST requests with a valid `_method` parameter.

- `Plug.Head` - converts HEAD requests to GET requests and strips the response body.

- `Plug.Session` - a plug that sets up session management. Note that `fetch_session/2` must still be explicitly called before using the session, as this plug just sets up how the session is fetched.

In the middle of the endpoint, there is also a conditional block:

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :hello
  end
```

This block is only executed in development. It enables:

* live reloading - if you change a CSS file, they are updated in-browser without refreshing the page;
* [code reloading](`Phoenix.CodeReloader`) - so we can see changes to our application without restarting the server;
* check repo status - which makes sure our database is up to date, raising a readable and actionable error otherwise.

### Router plugs

In the router, we can declare plugs inside pipelines:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {HelloWeb.LayoutView, :root}
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

As we will see in the [routing guide](routing.html), the pipelines themselves are plugs. There, we will also discuss all plugs in the `:browser` pipeline.

### Controller plugs

Finally, controllers are plugs too, so we can do:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  plug HelloWeb.Plugs.Locale, "en"
```

In particular, controller plugs provide a feature that allows us to execute plugs only within certain actions. For example, you can do:

```elixir
defmodule HelloWeb.PageController do
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
            conn |> put_flash(:info, "That message wasn't found") |> redirect(to: ~p"/")
          message ->
            if Authorizer.can_access?(user, message) do
              render(conn, :show, page: message)
            else
              conn |> put_flash(:info, "You can't access that page") |> redirect(to: ~p"/")
            end
        end
      :error ->
        conn |> put_flash(:info, "You must be logged in") |> redirect(to: ~p"/")
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
        conn |> put_flash(:info, "You must be logged in") |> redirect(to: ~p"/") |> halt()
    end
  end

  defp fetch_message(conn, _) do
    case find_message(conn.params["id"]) do
      nil ->
        conn |> put_flash(:info, "That message wasn't found") |> redirect(to: ~p"/") |> halt()
      message ->
        assign(conn, :message, message)
    end
  end

  defp authorize_message(conn, _) do
    if Authorizer.can_access?(conn.assigns[:user], conn.assigns[:message]) do
      conn
    else
      conn |> put_flash(:info, "You can't access that page") |> redirect(to: ~p"/") |> halt()
    end
  end
end
```

To make this all work, we converted the nested blocks of code and used `halt(conn)` whenever we reached a failure path. The `halt(conn)` functionality is essential here: it tells Plug that the next plug should not be invoked.

At the end of the day, by replacing the nested blocks of code with a flattened series of plug transformations, we are able to achieve the same functionality in a much more composable, clear, and reusable way.

To learn more about plugs, see the documentation for the [Plug project](`Plug`), which provides many built-in plugs and functionalities.

[`init/1`]: `c:Plug.init/1`
[`call/2`]: `c:Plug.call/2`
[`assign/3`]: `Plug.Conn.assign/3`
