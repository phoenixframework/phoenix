[Plug](https://github.com/elixir-lang/plug) is a specification for composable modules in between web applications and an abstraction layer for connection adapters of different web server. The basic idea of Plug is to unify the concept of a "connection" that you operate on. This differs from other HTTP middleware layers such as Rack, where the request and response are sepearated in the middleware stack.

## Plug and Phoenix
Plug lives at the heart of Phoenix's HTTP layer and Phoenix puts plug front and center. You interact with plugs at every step of the connection lifecycle and the core Phoenix compontents like Endpoints, Routers, and Controllers are all Just Plugs internally. Let's jump in and find out just what makes Plug so special. 


## The Plug Specification

At the simplest level, the Plug specification comes in two flavors, *function plugs* and *module plugs*

### Function Plugs
A function plug is any 2-arity function that accepts a connection (a `%Plug.Conn{}` struct) and options and returns a connection. These are called "function plugs". They look like this:

```elixir
def put_headers(conn, key_values) do
  Enum.reduce(key_values, conn, fn {k, v}, conn ->
    Plug.Conn.put_resp_header(k, v)
  end
end
```

Pretty simple, right? Any function that accept a connection and options and returns a connection can be a plug. This is how we used them to compose a series of transformations on our connection in Phoenix:

```elixir
defmodule HelloPhoenix.MessageController do
  use HelloPhoenix.Web, :controller
  
  plug :put_headers, %{content_encoding: "gzip", cache_control: "max-age=3600"}
  plug :put_layout, "bare.html"
  plug :action
  
  ...
end
```

By abiding by the plug contract, `put_headers/2`, `put_layout/2`, and event `action/2` turn a request into our application into a series of explicit transformations. But, It doesn't stop at simple tranformations. To really see how effective Plug's design is, let's imagine a scenario where we need to apply a sieries of different conditions and redirect or halt if a pre-condition fails. Without plug, we would end up with something like this:

```elixir
defmodule HelloPhoenix.MessageController do
  use HelloPhoenix.Web, :controller

  def show(conn, params) do
    case authenticate(conn) do
      {:ok, user} ->
        case find_message(params["id"]) do
          nil -> 
            conn |> put_flash("That message wasn't found") |> redirect(to: "/")
          message -> 
            case authorize_message(conn, params["id"])
              :ok -> 
                render conn, :show, page: find_page(params["id"])
              :error ->
                conn |> put_flash("You must be logged in") |> redirect(to: "/")
            end
        end
      :error ->
        conn |> put_flash("You can't access that page") |> redirect(to: "/")
    end
  end
end
```

Notice how just a few steps of authentication and authorization require complicated nested and duplication? Let's solve it with a couple plugs:

```elixir
defmodule HelloPhoenix.MessageController do
  use HelloPhoenix.Web, :controller

  plug :authenticate
  plug :find_message
  plug :authorize_message
  plug :action
  
  def show(conn, params) do
    render conn, :show, page: find_page(params["id"])
  end
  
  defp authenticate(conn, _) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        assign(conn, :user, user)
      :error ->
        conn |> put_flash("You must be logged in") |> redirect(to: "/") |> halt
    end
  end

  defp find_message(conn, _) do  
    case find_message(params["id"]) do
      nil -> 
        conn |> put_flash("That message wasn't found") |> redirect(to: "/") |> halt
      message ->
        assign(conn, :message, message)
    end
  end
  
  defp authorize_message(conn, _) do
    if Authorizer.can_acces?(conn.assigns[:user], conn.assigns[:message]) do
      conn
    else
      conn |> put_flash("You can't access that page") |> redirect(to: "/") |> halt
    end
  end
end
```

By replacing the nested blocks of code with a flattened series of plug transformations, we were able to take almost the identical code and make it much more composable, clear, and resuable.

Now, let's look at the other flavor plugs come in: Module Plugs.

### Module Plugs

Module plugs are another type of Plug that lets you group a connection transformation into a module. The module only needs to implement two functions:

- `init/1` initializes any arguments or options passed to be pased to call/2
- `call/2` carries out the connectiont transformation. `call/2` is just a function plug that we saw earlier


To see this in action, lets write a Module Plug that that puts the `:locale` assign into the connectiona assigns for downstream use in other plugs, the controller actions, and our views.

```elixir
defmodule HelloPhoenix.Plugs.Locale
  import Plug.Conn
  
  @locales ["en", "fr", "de"]
  
  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}}, _default) when loc in @locales
    assign(conn, :locale, loc))
  end
  def call(conn, default), do: assign(conn, :locale, default)
end

defmodule HelloPhoenix.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :accepts, ~w(html)
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug HelloPhoenix.Plugs.Locale, "en"
  end
  ...
```

By using a module plug, we were able to add it to our browser pipeline via `plug HelloPhoenix.Plugs.Locale, "en"`. We can see that using the `init/1` callback, we passed a default locale to fallback to if none is present. We also made use of pattern matching to define multiple `call/2` function heads to validate the locale in the params, and otherwise fallback to "en". 

That's all there is to plug. Phoenix embraces the plug design of composable transformations all the way up and own the stack. This is just your first taste, but get used to asking yourself "Could I put this in a plug?". The answer is usually yes!




