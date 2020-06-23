# Custom Error Pages

Phoenix has a view called the `ErrorView` which lives in `lib/hello_web/views/error_view.ex`. The purpose of the `ErrorView` is to handle errors in a general way, from one centralized location.

## The ErrorView

For new applications, the ErrorView looks like this:

```elixir
defmodule HelloWeb.ErrorView do
  use HelloWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
```

Before we dive into this, let's see what the rendered `404 Not Found` message looks like in a browser. In the development environment, Phoenix will debug errors by default, showing us a very informative debugging page. What we want here, however, is to see what page the application would serve in production. In order to do that we need to set `debug_errors: false` in `config/dev.exs`.

```elixir
import Config

config :hello, HelloWeb.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  code_reloader: true,
  . . .
```

After modifying our config file, we need to restart our server in order for this change to take effect. After restarting the server, let's go to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) for a running local application and see what we get.

Ok, that's not very exciting. We get the bare string "Not Found", displayed without any markup or styling.

The first question is, where does that error string come from? The answer is right in the `ErrorView`.

```elixir
def template_not_found(template, _assigns) do
  Phoenix.Controller.status_message_from_template(template)
end
```

Great, so we have this `template_not_found/2` function that takes a template and an `assigns` map, which we ignore. The `template_not_found/2` is invoked whenever a Phoenix.View attempts to render a template but no template is found.

In other words, to provide custom error pages, we could simply define a proper `render/2` function clause in `HelloWeb.ErrorView`.

```elixir
def render("404.html", _assigns) do
  "Page Not Found"
end
```

But we can do even better.

Phoenix generates an `ErrorView` for us, but it doesn't give us a `lib/hello_web/templates/error` directory. Let's create one now. Inside our new directory, let's add a template, `404.html.eex` and give it some markup – a mixture of our application layout and a new `div` with our message to the user.

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">

    <title>Welcome to Phoenix!</title>
    <link rel="stylesheet" href="/css/app.css">
  </head>

  <body>
    <div class="container">
      <div class="header">
        <ul class="nav nav-pills pull-right">
          <li><a href="https://hexdocs.pm/phoenix/overview.html">Get Started</a></li>
        </ul>
        <span class="logo"></span>
      </div>

      <div class="phx-hero">
        <p>Sorry, the page you are looking for does not exist.</p>
      </div>

      <div class="footer">
        <p><a href="https://phoenixframework.org">phoenixframework.org</a></p>
      </div>

    </div> <!-- /container -->
    <script src="/js/app.js"></script>
  </body>
</html>
```

Now when we go back to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path), we should see a much nicer error page. It is worth noting that we did not render our `404.html.eex` template through our application layout, even though we want our error page to have the look and feel of the rest of our site. This is to avoid circular errors. For example, what happens if our application failed due to an error in the layout? Attempting to render the layout again will just trigger another error. So ideally we want to minimize the amount of dependencies and logic in our error templates, sharing only what is necessary.

## Custom Exceptions

Elixir provides a macro called `defexception` for defining custom exceptions. Exceptions are represented as structs, and structs need to be defined inside of modules.

In order to create a custom exception, we need to define a new module. Conventionally this will have "Error" in the name. Inside of that module, we need to define a new exception with `defexception`.

```elixir
defmodule MyApp.SomethingNotFoundError do
  defexception [:message]
end
```

You can raise your new exception like this:

```elixir
raise MyApp.SomethingNotFoundError, "oops"
```

By default, Plug and Phoenix will treat all exceptions as 500 errors. However, Plug provides a protocol called `Plug.Exception` where we are able to customize the status and add actions that exception structs can return on the debug error page.

If we wanted to supply a status of 404 for an `MyApp.SomethingNotFoundError`, we could do it by defining an implementation for the `Plug.Exception` protocol like this:

```elixir
defimpl Plug.Exception, for: MyApp.SomethingNotFoundError do
  def status(_exception), do: 404
  def actions(_exception), do: []
end
```

Alternatively, you could define a `plug_status` field directly in the exception struct:

```elixir
defmodule MyApp.SomethingNotFoundError do
  defexception [:message, plug_status: 404]
end
```

However, implementing the `Plug.Exception` protocol by hand can be convenient in certain occasions, such as when providing Actionable Errors.

## Actionable Errors

Exception actions are functions that can be triggered by the error page, and they're basically a list of maps defining a `label` and a `handler` to be executed.

They are rendered in the error page as a collection of buttons and follow the format of: `[%{label: String.t(), handler: {module(), function :: atom(), args :: []}}]`.

If we wanted to return some actions for an `MyApp.SomethingNotFoundError` we would implement `Plug.Exception` like this:

```elixir
defimpl Plug.Exception, for: MyApp.SomethingNotFoundError do
  def status(_exception), do: 404
  def actions(_exception), do: [%{
      label: "Run seeds",
      handler: {Code, :eval_file, "priv/repo/seeds.exs"}
    }]
end
```
