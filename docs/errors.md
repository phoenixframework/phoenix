# Custom Errors

Phoenix provides an `ErrorView`, `lib/hello_web/views/error_view.ex`, to render errors in our applications. The full module name will include the name of our application, as in `Hello.ErrorView`.

Phoenix will detect any 400 or 500 status level errors in our application and use the `render/2` function in our `ErrorView` to render an appropriate error template. We get default implementations for 404 and 500 HTML errors, but we can add any clauses to `render/2` that we might need. Any errors which don't match an existing clause of `render/2` will be caught by `template_not_found/2`.

We can also customize the implementation of any of these functions however we like.

Here's what the `ErrorView` looks like.

```elixir
defmodule Hello.ErrorView do
  use Hello.Web, :view

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Server internal error"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
```

> NOTE: In the development environment, this behavior will be overridden. Instead, we will get a really great debugging page. In order to see the `ErrorView` in action, we'll need to set `debug_errors:` to `false` in `config/dev.exs`. The server must be restarted for the changes to become effective.

```elixir
config :hello, HelloWeb.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  code_reloader: true,
  cache_static_lookup: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch"]]
```

To learn more about custom error pages, please see [The Error View](views.html#the-errorview) section of the View Guide.

#### Custom Errors

Elixir provides a macro called `defexception` for defining custom exceptions. Exceptions are represented as structs, and structs need to be defined inside of modules.

In order to create a custom error, we need to define a new module. Conventionally this will have "Error" in the name. Inside of that module, we need to define a new exception with `defexception`.

We can also define a module within a module to provide a namespace for the inner module.

Here's an example from the [Phoenix.Router](https://github.com/phoenixframework/phoenix/blob/master/lib/phoenix/router.ex) which demonstrates all of these ideas.

```elixir
defmodule Phoenix.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn   = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path   = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{message: "no route found for #{conn.method} #{path} (#{inspect router})",
      conn: conn, router: router}
    end
  end
. . .
end
```

Plug provides a protocol called `Plug.Exception` specifically for adding a status to exception structs.

If we wanted to supply a status of 404 for an `Ecto.NoResultsError`, we could do it by defining an implementation for the `Plug.Exception` protocol like this:

```elixir
defimpl Plug.Exception, for: Ecto.NoResultsError do
  def status(_exception), do: 404
end
```

Note that this is just an example: Phoenix [already does this](https://github.com/phoenixframework/phoenix_ecto/blob/master/lib/phoenix_ecto/plug.ex) for `Ecto.NoResultsError`, so you don't have to.
