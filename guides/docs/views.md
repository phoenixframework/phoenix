# Views

Phoenix views have two main jobs. First and foremost, they render templates (this includes layouts). The core function involved in rendering, `render/3`, is defined in Phoenix itself in the `Phoenix.View` module. Views also provide functions which take raw data and make it easier for templates to consume. If you are familiar with decorators or the facade pattern, this is similar.

## Rendering Templates

Phoenix assumes a strong naming convention from controllers to views to the templates they render. The `PageController` requires a `PageView` to render templates in the `lib/hello_web/templates/page` directory. If we want to, we can change the directory Phoenix considers to be the template root. Phoenix provides a `view/0` function in the `HelloWeb` module defined in `lib/hello_web.ex`. The first line of `view/0` allows us to change our root directory by changing the value assigned to the `:root` key.

A newly generated Phoenix application has three view modules - `ErrorView`, `LayoutView`, and `PageView` -  which are all in the, `lib/hello_web/views` directory.

Let's take a quick look at the `LayoutView`.

```elixir
defmodule HelloWeb.LayoutView do
  use HelloWeb, :view
end
```

That's simple enough. There's only one line, `use HelloWeb, :view`. This line calls the `view/0` function we just saw above. Besides allowing us to change our template root, `view/0` exercises the `__using__` macro in the `Phoenix.View` module. It also handles any module imports or aliases our application's view modules might need.

At the top of this guide, we mentioned that views are a place to put functions for use in our templates. Let's experiment with that a little bit.

Let's open up our application layout template, `lib/hello_web/templates/layout/app.html.eex`, and change this line,

```html
<title>Hello Phoenix!</title>
```

to call a `title/0` function, like this.

```elixir
<title><%= title() %></title>
```

Now let's add a `title/0` function to our `LayoutView`.

```elixir
defmodule HelloWeb.LayoutView do
  use HelloWeb, :view

  def title do
    "Awesome New Title!"
  end
end
```

When we reload the Welcome to Phoenix page, we should see our new title.

The `<%=` and `%>` are from the Elixir [EEx](https://hexdocs.pm/eex/1.5.1/EEx.html) project. They enclose executable Elixir code within a template. The `=` tells EEx to print the result. If the `=` is not there, EEx will still execute the code, but there will be no output. In our example, we are calling the `title/0` function from our `LayoutView` and printing the output into the title tag.

Note that we didn't need to fully qualify `title/0` with `HelloWeb.LayoutView` because our `LayoutView` actually does the rendering. In fact, "templates" in Phoenix are really just function definitions on their view module. You can try this out by temporarily deleting your `lib/hello_web/templates/page/index.html.eex` file and adding this function clause to your `PageView` module in `lib/hello_web/views/page_view.ex`.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def render("index.html", assigns) do
    "rendering with assigns #{inspect Map.keys(assigns)}"
  end
end
```

Now if you fire up the server with `mix phx.server` and visit `http://localhost:4000`, you should see the following text below your layout header instead of the main template page:
```
rendering with assigns [:conn, :view_module, :view_template]
```

Pretty neat, right? At compile-time, Phoenix precompiles all `*.html.eex` templates and turns them into `render/2` function clauses on their respective view modules. At runtime, all templates are already loaded in memory. There's no disk reads, complex file caching, or template engine computation involved. This is also why we were able to define functions like `title/0` in our `LayoutView` and they were immediately available inside the layout's `app.html.eex` – the call to `title/0` was just a local function call!

When we `use HelloWeb, :view`, we get other conveniences as well. Since the `view/0` function imports `HelloWeb.Router.Helpers`, we don't have to fully qualify path helpers in templates. Let's see how that works by changing the template for our Welcome to Phoenix page.

Let's open up the `lib/hello_web/templates/page/index.html.eex` and locate this stanza.

```html
<div class="jumbotron">
  <h2><%= gettext "Welcome to %{name}!", name: "Phoenix" %></h2>
  <p class="lead">A productive web framework that<br>does not compromise speed and maintainability.</p>
</div>
```

Then let's add a line with a link back to the same page. (The objective is to see how path helpers respond in a template, not to add any functionality.)

```html
<div class="jumbotron">
  <h2><%= gettext "Welcome to %{name}!", name: "Phoenix" %></h2>
  <p class="lead">A productive web framework that<br>does not compromise speed and maintainability.</p>
  <p><a href="<%= page_path @conn, :index %>">Link back to this page</a></p>
</div>
```

Now we can reload the page and view source to see what we have.

```html
<a href="/">Link back to this page</a>
```

Great, `page_path/2` evaluated to `/` as we would expect, and we didn't need to qualify it with `Phoenix.View`.

### More About Views

You might be wondering how views are able to work so closely with templates.

The `Phoenix.View` module gains access to template behavior via the `use Phoenix.Template` line in its `__using__/1` macro. `Phoenix.Template` provides many convenience methods for working with templates - finding them, extracting their names and paths, and much more.

Let's experiment a little with one of the generated views Phoenix provides us, `lib/hello_web/views/page_view.ex`. We'll add a `message/0` function to it, like this.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def message do
    "Hello from the view!"
  end
end
```

Now let's create a new template to play around with, `lib/hello_web/templates/page/test.html.eex`.

```html
This is the message: <%= message() %>
```

This doesn't correspond to any action in our controller, but we'll exercise it in an `iex` session. At the root of our project, we can run `iex -S mix`, and then explicitly render our template.

```console
iex(1)> Phoenix.View.render(HelloWeb.PageView, "test.html",
%{})
  {:safe, [["" | "This is the message: "] | "Hello from the view!"]}
```
As we can see, we're calling `render/3` with the individual view responsible for our test template, the name of our test template, and an empty map representing any data we might have wanted to pass in. The return value is a tuple beginning with the atom `:safe` and the resultant io list of the interpolated template. "Safe" here means that Phoenix has escaped the contents of our rendered template. Phoenix defines its own `Phoenix.HTML.Safe` protocol with implementations for atoms, bitstrings, lists, integers, floats, and tuples to handle this escaping for us as our templates are rendered into strings.

What happens if we assign some key value pairs to the third argument of `render/3`? In order to find out, we need to change the template just a bit.

```html
I came from assigns: <%= @message %>
This is the message: <%= message() %>
```

Note the `@` in the top line. Now if we change our function call, we see a different rendering after recompiling `PageView` module.

```console
iex(2)> r HelloWeb.PageView
warning: redefining module HelloWeb.PageView (current version loaded from _build/dev/lib/hello/ebin/Elixir.HelloWeb.PageView.beam)
  lib/hello_web/views/page_view.ex:1

{:reloaded, HelloWeb.PageView, [HelloWeb.PageView]}

iex(3)> Phoenix.View.render(HelloWeb.PageView, "test.html", message: "Assigns has an @.")
{:safe,
  [[[["" | "I came from assigns: "] | "Assigns has an @."] |
  "\nThis is the message: "] | "Hello from the view!"]}
 ```
Let's test out the HTML escaping, just for fun.

```console
iex(4)> Phoenix.View.render(HelloWeb.PageView, "test.html", message: "<script>badThings();</script>")
{:safe,
  [[[["" | "I came from assigns: "] |
     "&lt;script&gt;badThings();&lt;/script&gt;"] |
    "\nThis is the message: "] | "Hello from the view!"]}
```

If we need only the rendered string, without the whole tuple, we can use the `render_to_iodata/3`.

 ```console
 iex(5)> Phoenix.View.render_to_iodata(HelloWeb.PageView, "test.html", message: "Assigns has an @.")
 [[[["" | "I came from assigns: "] | "Assigns has an @."] |
   "\nThis is the message: "] | "Hello from the view!"]
  ```

### A Word About Layouts

Layouts are just templates. They have a view, just like other templates. In a newly generated app, this is `lib/hello_web/views/layout_view.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question! If we look at `lib/hello_web/templates/layout/app.html.eex`, just about in the middle of the `<body>`, we will see this.

```html
<%= render @view_module, @view_template, assigns %>
```

This is where the view module and its template from the controller are rendered to a string and placed in the layout.

## The ErrorView

Phoenix has a view called the `ErrorView` which lives in `lib/hello_web/views/error_view.ex`. The purpose of the `ErrorView` is to handle two of the most common errors - `404 not found` and `500 internal error` - in a general way, from one centralized location. Let's see what it looks like.

```elixir
defmodule HelloWeb.ErrorView do
  use HelloWeb, :view

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

Before we dive into this, let's see what the rendered `404 not found` message looks like in a browser. In the development environment, Phoenix will debug errors by default, showing us a very informative debugging page. What we want here, however, is to see what page the application would serve in production. In order to do that we need to set `debug_errors: false` in `config/dev.exs`.

```elixir
use Mix.Config

config :hello, HelloWeb.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  code_reloader: true,
  . . .
```

After modifying our config file, we need to restart our server in order for this change to take effect. After restarting the server, let's go to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) for a running local application and see what we get.

Ok, that's not very exciting. We get the bare string "Page not found", displayed without any markup or styling.

Let's see if we can use what we already know about views to make this a more interesting error page.

The first question is, where does that error string come from? The answer is right in the `ErrorView`.

```elixir
def render("404.html", _assigns) do
  "Page not found"
end
```

Great, so we have a `render/2` function that takes a template and an `assigns` map, which we ignore. Where is this `render/2` function being called from? The answer is the `render/5` function defined in the `Phoenix.Endpoint.RenderErrors` module. The whole purpose of this module is to catch errors and render them with a view, in our case, the `HelloWeb.ErrorView`. Now that we understand how we got here, let's make a better error page. Phoenix generates an `ErrorView` for us, but it doesn't give us a `lib/hello_web/templates/error` directory. Let's create one now. Inside our new directory, let's add a template, `404.html.eex` and give it some markup - a mixture of our application layout and a new `div` with our message to the user.


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
  </body>
</html>
```

Now we can use the `render/2` function we saw above when we were experimenting with rendering in the `iex` session. Since we know that Phoenix will precompile the `404.html.eex` template as a `render("index.html.eex", assigns)` function clause, we can delete the clause from our ErrorView.

```diff
- def render("404.html", _assigns) do
-  render("not_found.html", %{})
- end
```

When we go back to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path), we should see a much nicer error page. It is worth noting that we did not render our `404.html.eex` template through our application layout, even though we want our error page to have the look and feel of the rest of our site. The main reason is that it's easy to run into edge case issues while handling errors globally. If we want to minimize duplication between our application layout and our `404.html.eex` template, we can implement shared templates for our header and footer. Please see the [Template Guide](templates.html) for more information. Of course, we can do these same steps with the `def render("500.html", _assigns) do` clause in our `ErrorView` as well. We can also use the `assigns` map passed into any `render/2` clause in the `ErrorView`, instead of discarding it, in order to display more information in our templates.

## Rendering JSON

The view's job is not only to render HTML templates. Views are about data presentation. Given a bag of data, the view's purpose is to present that in a meaningful way given some format, be it HTML, JSON, CSV, or others. Many web apps today return JSON to remote clients, and Phoenix views are *great* for JSON rendering. Phoenix uses [Poison](https://github.com/devinus/poison) to encode Maps to JSON, so all we need to do in our views is format the data we'd like to respond with as a Map, and Phoenix will do the rest. It is possible to respond with JSON back directly from the controller and skip the View. However, if we think about a controller as having the responsibilities of receiving a request and fetching data to be sent back, data manipulation and formatting don't fall under those responsibilities. A view gives us a module responsible for formatting and manipulating the data. Let's take our `PageController`, and see what it might look like when we respond with some static page maps as JSON, instead of HTML.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def show(conn, _params) do
    page = %{title: "foo"}

    render conn, "show.json", page: page
  end

  def index(conn, _params) do
    pages = [%{title: "foo"}, %{title: "bar"}]

    render conn, "index.json", pages: pages
  end
end
```

Here, we have our `show/2` and `index/2` actions returning static page data. Instead of passing in `"show.html"` to `render/3` as the template name, we pass `"show.json"`. This way, we can have views that are responsible for rendering HTML as well as JSON by pattern matching on different file types.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def render("index.json", %{pages: pages}) do
    %{data: render_many(pages, HelloWeb.PageView, "page.json")}
  end

  def render("show.json", %{page: page}) do
    %{data: render_one(page, HelloWeb.PageView, "page.json")}
  end

  def render("page.json", %{page: page}) do
    %{title: page.title}
  end
end
```

In the view we see our `render/2` function pattern matching on `"index.json"`, `"show.json"`, and `"page.json"`. In our controller `show/2` function, `render conn, "show.json", page: page` will pattern match on the matching name and extension in the view `render/3` functions. In other words, `render conn, "index.json", pages: pages` will call `render("index.json", %{pages: pages})` The `render_many/3` function takes the data we want to respond with (`pages`), a `View`, and a string to pattern match on the `render/3` function defined on `View`. It will map over each item in `pages`, and pass the item to the `render/3` function in `View` matching the file string. `render_one/3` follows, the same signature, ultimately using the `render/3` matching `page.json` to specify what each `page` looks like. The `render/3` matching `"index.json"` will respond with JSON as you would expect:

```javascript
  {
    "data": [
      {
       "title": "foo"
      },
      {
       "title": "bar"
      },
   ]
  }
```

And the `render/3` matching `"show.json"`:

```javascript
  {
    "data": {
      "title": "foo"
    }
  }
```

It's useful to build our views like this so they can be composable. Imagine a situation where our `Page` has a `has_many` relationship with `Author`, and depending on the request, we may want to send back `author` data with the `page`. We can easily accomplish this with a new `render/3`:


```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view
  alias HelloWeb.AuthorView

  def render("page_with_authors.json", %{page: page}) do
    %{title: page.title,
      authors: render_many(page.authors, AuthorView, "author.json")}
  end

  def render("page.json", %{page: page}) do
    %{title: page.title}
  end
end
```

The name used in assigns is determined from the view. For example the `PageView` will use `%{page: page}` and the `AuthorView` will use `%{author: author}`. This can be overridden with the `as` option. Let's assume that the author view uses `%{writer: writer}` instead of `%{author: author}`:

```elixir
  def render("page_with_authors.json", %{page: page}) do
    %{title: page.title,
      authors: render_many(page.authors, AuthorView, "author.json", as: :writer)}
  end
```
