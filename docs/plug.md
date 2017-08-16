# Plug

Plug lives at the heart of Phoenix's HTTP layer, and Phoenix puts Plug front and center. We interact with plugs at every step of the connection lifecycle, and the core Phoenix components like Endpoints, Routers, and Controllers are all just Plugs internally. Let's jump in and find out just what makes Plug so special.

[Plug](https://github.com/elixir-lang/plug) is a specification for composable modules in between web applications. It is also an abstraction layer for connection adapters of different web servers. The basic idea of Plug is to unify the concept of a "connection" that we operate on. This differs from other HTTP middleware layers such as Rack, where the request and response are separated in the middleware stack.

At the simplest level, the Plug specification comes in two flavors: *function plugs* and *module plugs*.

## Function Plugs
In order to act as a plug, a function simply needs to accept a connection struct (`%Plug.Conn{}`) and options. It also needs to return the connection struct. Any function that meets those criteria will do. Here's an example.

```elixir
def put_headers(conn, key_values) do
  Enum.reduce key_values, conn, fn {k, v}, conn ->
    Plug.Conn.put_resp_header(conn, to_string(k), v)
  end
end
```

Pretty simple, right?

This is how we use them to compose a series of transformations on our connection in Phoenix:

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  plug :put_headers, %{content_encoding: "gzip", cache_control: "max-age=3600"}
  plug :put_layout, "bare.html"

  ...
end
```

By abiding by the plug contract, `put_headers/2`, `put_layout/2`, and even `action/2` turn an application request into a series of explicit transformations. It doesn't stop there. To really see how effective Plug's design is, let's imagine a scenario where we need to check a series of conditions and then either redirect or halt if a condition fails. Without plug, we would end up with something like this:

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  def show(conn, params) do
    case authenticate(conn) do
      {:ok, user} ->
        case find_message(params["id"]) do
          nil ->
            conn |> put_flash(:info, "That message wasn't found") |> redirect(to: "/")
          message ->
            case authorize_message(conn, params["id"]) do
              :ok ->
                render conn, :show, page: find_message(params["id"])
              :error ->
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
  plug :find_message
  plug :authorize_message

  def show(conn, params) do
    render conn, :show, page: find_message(params["id"])
  end

  defp authenticate(conn, _) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        assign(conn, :user, user)
      :error ->
        conn |> put_flash(:info, "You must be logged in") |> redirect(to: "/") |> halt()
    end
  end

  defp find_message(id), do: ...
  defp find_message(conn, _) do
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

By replacing the nested blocks of code with a flattened series of plug transformations, we are able to achieve the same functionality in a much more composable, clear, and reusable way.

Now let's look at the other flavor plugs come in, module plugs.

## Module Plugs

Module plugs are another type of Plug that let us define a connection transformation in a module. The module only needs to implement two functions:

- `init/1` which initializes any arguments or options to be passed to `call/2`
- `call/2` which carries out the connection transformation. `call/2` is just a function plug that we saw earlier


To see this in action, let's write a module plug that puts the `:locale` key and value into the connection assign for downstream use in other plugs, controller actions, and our views.

```elixir
defmodule HelloWeb.Plugs.Locale do
  import Plug.Conn

  @locales ["en", "fr", "de"]

  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}} = conn, _default) when loc in @locales do
    assign(conn, :locale, loc)
  end
  def call(conn, default), do: assign(conn, :locale, default)
end

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

That's all there is to Plug. Phoenix embraces the plug design of composable transformations all the way up and down the stack. This is just the first taste. If we ask ourselves, "Could I put this in a plug?" The answer is usually, "Yes!"
