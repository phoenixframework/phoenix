Phoenix views have two main jobs. First and foremost, they render templates (this includes layouts). The core function involved in rendering, `render/3`, is defined in Phoenix itself in the `Phoenix.View` module. Views also provide functions which take raw data and make it easier for templates to consume. If you are familiar with decorators or the facade pattern, this is similar.

Phoenix assumes a strong naming convention from controllers to views to the templates they render. The `PageController` requires a `PageView` to render templates in the `web/templates/page` directory.

If we want to, we can change the directory Phoenix considers to be the template root. Phoenix provides a `view/0` function in the `HelloPhoenix.Web` module defined in `web/web.ex`. The first line of `view/0` allows us to change our root directory by changing the value assigned to the `:root` key.

A newly generated Phoenix application has three view modules - `ErrorView`, `LayoutView`, and `PageView` -  which are all in the, `web/views` directory.

Let's take a quick look at the `LayoutView`.

```elixir
defmodule HelloPhoenix.LayoutView do
  use HelloPhoenix.Web, :view
end
```

That's simple enough. There's only one line, `use HelloPhoenix.Web, :view`. This line calls the `view/0` function we just saw above. Besides allowing us to change our template root, `view/0` exercises the `__using__` macro in the `Phoenix.View` module. It also handles any module imports or aliases our application's view modules might need.

At the top of this file, we mentioned that views are a place to put functions for use in our templates. Let's experiment with that a little bit.

Let's open up our application layout template, `templates/layout/application.html.eex`, and change this line,

```html
<title>Hello Phoenix!</title>
```

to call a `title/0` function, like this.

```elixir
<title><%= title %></title>
```

Now let's add a `title/0` function to our `LayoutView`.

```elixir
defmodule HelloPhoenix.LayoutView do
  use HelloPhoenix.Web, :view

  def title do
    "Awesome New Title!"
  end
end
```

When we reload the Welcome to Phoenix page, we should see our new title.

The `<%=` and `%>` are from the Elixir [Eex](http://elixir-lang.org/docs/stable/eex/) project. They enclose executable Elixir code within a template. The `=` tells Eex to print the result. If the `=` is not there, Eex will still execute the code, but there will be no output. In our example, we are calling the `title/0` function from our `LayoutView` and printing the output into the title tag.

Note that we didn't need to fully qualify `title/0` with `HelloPhoenix.LayoutView` because our `LayoutView` actually does the rendering.

When we `use HelloPhoenix.Web, :view`, we get other conveniences as well. Since the `view/0` function imports `HelloPhoenix.Router.Helpers`, we don't have to fully qualify path helpers in templates. Let's see how that works by changing the template for our Welcome to Phoenix page.

Let's open up the `templates/page/index.html.eex` and locate this stanza.

```html
<div class="jumbotron">
  <h2>Welcome to Phoenix!</h2>
  <p class="lead">Most frameworks make you choose between speed and a productive environment. <a href="http://phoenixframework.org">Phoenix</a> and <a href="http://elixir-lang.org">Elixir</a> give you both.</p>
</div>
```

Then let's add a line with a link back to the same page. (The object is to see how path helpers respond in a template, not to add any functionality.)

```html
<div class="jumbotron">
  <h2>Welcome to Phoenix!</h2>
  <p class="lead">Most frameworks make you choose between speed and a productive environment. <a href="http://phoenixframework.org">Phoenix</a> and <a href="http://elixir-lang.org">Elixir</a> give you both.</p>
  <p><a href="<%= page_path @conn, :index %>">Link back to ourselves</a></p>
</div>
```

Now we can reload the page and view source to see what we have.

```html
<a href="/">Link back to ourselves</a>
```

Great, `page_path/2` evaluated to `/` as we would expect, and we didn't need to qualify it with `HelloPhoenix.View`.

### More About Views

You might be wondering how views are able to work so closely with templates.

The `Phoenix.View` module gains access to template behavior via the `use Phoenix.Template` line in its `__using__/1` macro. `Phoenix.Template` provides many convenience methods for working with templates - finding them, extracting their names and paths, and much more.

Let's experiment a little with one of the generated views Phoenix provides us, `web/views/page_view.ex`. We'll add a `message/0` function to it, like this.

```elixir
defmodule HelloPhoenix.PageView do
  use HelloPhoenix.Web, :view

  def message do
    "Hello from the view!"
  end
end
```

Now let's create a new template to play around with, `web/templates/page/test.html.eex`.

```html
This is the message: <%= message %>
```

This doesn't correspond to any action in our controller, but we'll exercise it in an `iex` session. At the root of our project, we can run `iex -S mix`, and then explicitly render our template.

```console
iex(1)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", %{})
  {:safe, [["" | "This is the message: "] | "Hello from the view!"]}
```
As we can see, we're calling `render/3` with the individual view responsible for our test template, the name of our test template, and an empty map representing any data we might have wanted to pass in.

The return value is a tuple beginning with the atom `:safe` and the resultant string of the interpolated template.

"Safe" here means that Phoenix has escaped the contents of our rendered template. Phoenix defines its own `Phoenix.HTML.Safe` protocol with implementations for atoms, bitstrings, lists, integers, floats, and tuples to handle this escaping for us as our templates are rendered into strings.

What happens if we assign some key value pairs to the third argument of `render/3`? In order to find out, we need to change the template just a bit.

```html
I came from assigns: <%= @message %>
This is the message: <%= message %>
```

Note the `@` in the top line. Now if we change our function call, we see a different rendering after recompiling `PageView` module.

```console
iex(2)> r HelloPhoenix.PageView
web/views/page_view.ex:1: warning: redefining module HelloPhoenix.PageView
{:reloaded, HelloPhoenix.PageView, [HelloPhoenix.PageView]}

iex(3)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", message: "Assigns has an @.")
{:safe,
  [[[["" | "I came from assigns: "] | "Assigns has an @."] |
  "\nThis is the message: "] | "Hello from the view!"]}
 ```
Let's test out the HTML escaping, just for fun.

```console
iex(4)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", message: "<script>badThings();</script>")
{:safe,
  [[[["" | "I came from assigns: "] |
     "&lt;script&gt;badThings();&lt;/script&gt;"] |
    "\nThis is the message: "] | "Hello from the view!"]}
```

If we need only the rendered string, without the whole tuple, we can use the `render_to_iodata/3`.

 ```console
 iex(5)> Phoenix.View.render_to_iodata(HelloPhoenix.PageView, "test.html", message: "Assigns has an @.")
 [[[["" | "I came from assigns: "] | "Assigns has an @."] |
   "\nThis is the message: "] | "Hello from the view!"]
  ```

### A Word About Layouts

Layouts are just templates. They have a view, just like other templates. In a newly generated app, this is `web/views/layout_view.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question!

When a template is rendered, the layout view will assign `@inner` with the rendered contents of the template. For HTML templates, `@inner` will be always marked as safe.

If we look at `web/templates/layout/application.html.eex`, just about in the middle of the `<body>`, we will see this.

```html
<%= @inner %>
```

This is where the rendered string from the template will be placed.

### The ErrorView

Phoenix recently added a new view to every generated application, the `ErrorView` which lives in `web/views/error_view.ex`. The purpose of the `ErrorView` is to handle two of the most common errors - `404 not found` and `500 internal error` - in a general way, from one centralized location. Let's see what it looks like.

```elixir
defmodule HelloPhoenix.ErrorView do
  use HelloPhoenix.Web, :view

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

Before we dive into this, let's see what the rendered `404 not found` message looks like in a browser. In the development environment, Phoenix will debug errors by default, showing us a very informative debugging page. What we want here, however, is to see what page the application would serve in production. In order to do that we need to change some configuration in `config/dev.exs`. We change `debug_errors: false` and add `catch_errors: true`.

```elixir
use Mix.Config

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  catch_errors: true,
  code_reloader: true,
  . . .
```

Now let's go to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) for a running local application and see what we get.

Ok, that's not very exciting. We get the bare string "Page not found", displayed without any markup or styling.

Let's see if we can use what we already know about views to make this a more interesting error page.

The first question is, where does that error string come from? The answer is right in the `ErrorView`.

```elixir
def render("404.html", _assigns) do
  "Page not found"
end
```

Great, so we have a `render/2` function that takes a template and an `assigns` map, which we ignore. Where is this `render/2` function being called from?

The answer is the `render/5` function defined in the `Phoenix.Endpoint.ErrorHandler` module. The whole purpose of this module is to catch errors and render them with a view, in our case, the `HelloPhoenix.ErrorView`.

Now that we understand how we got here, let's make a better error page.

Phoenix generates an `ErrorView` for us, but it doesn't give us a `web/templates/error` directory. Let's create one now. Inside our new directory, let's add a template, `not_found.html.eex` and give it some markup - a mixture of our application layout and a new `div` with our message to the user.


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
          <li><a href="http://www.phoenixframework.org/docs">Get Started</a></li>
        </ul>
        <span class="logo"></span>
      </div>

      <div class="jumbotron">
        <p>Sorry, the page you are looking for does not exist.</p>
      </div>

      <div class="footer">
        <p><a href="http://phoenixframework.org">phoenixframework.org</a></p>
      </div>

    </div> <!-- /container -->
    <script src="/js/app.js"></script>
    <script>require("web/static/js/app")</script>
  </body>
</html>
```

Now we can use the `render/2` function we saw above when we were experimenting with rendering in the `iex` session.

Our `render/2` function should look like this when we've modified it.

```elixir
def render("404.html", _assigns) do
  render("not_found.html", %{})
end
```

When we go back to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path), we should see a much nicer error page.

It is worth noting that we did not render our `not_found.html.eex` template through our application layout, even though we want our error page to have the look and feel of the rest of our site. The main reason is that it's easy to run into edge case issues while handling errors globally.

If we want to minimize duplication between our application layout and our `not_found.html.eex` template, we can implement shared templates for our header and footer. Please see the [Template Guide](http://www.phoenixframework.org/docs/templates#section-shared-templates-across-views) for more information.

Of course, we can do these same steps with the `def render("500.html", _assigns) do` clause in our `ErrorView` as well.

We can also use the `assigns` map passed into any `render/2` clause in the `ErrorView`, instead of discarding it, in order to display more information in our templates.
