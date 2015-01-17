Phoenix views have two main jobs. First and foremost, they render templates (this includes layouts). The core function involved in rendering, `render/3`, is defined in `Phoenix.View`. Views also provide functions which take raw data and make it easier for templates to consume. If you are familiar with decorators or the facade pattern, this is similar.

Phoenix defines view behavior in layers. The deepest level is `Phoenix.View`, from Phoenix itself, which doesn't appear in our generated application code. Since Phoenix is a dependency of our application, we have access to `Phoenix.View` even though we don't see it directly.

The next layer is the main application view, which will be `web/view.ex` in a newly generated app. The main view brings in all the behavior from `Phoenix.View` via `use Phoenix.View`. In the main view we can also import functions, use modules, and alias modules which need to be available to other views.

Individual views are the final layer. These will all gain access to the behavior collected in the main application view by using it. In our case, that is `use HelloPhoenix.View`. A newly generated app will have two of these, `web/views/layout_view.ex` and `web/views/page_view.ex`.

Looking back up the chain, individual views use the main view which uses the Phoenix view.

It's important to note that the scope of the main view is global to all views and templates in the application, and individual views are scoped to a single directory of templates.

### Main Application View

Let's take a look at the main view.

```elixir
defmodule HelloPhoenix.View do
  use Phoenix.View, root: "web/templates"

  # The quoted expression returned by this block is applied
  # to this module and all other views that use this module.
  using do
    quote do
      # Import common functionality
      import HelloPhoenix.Router.Helpers

      # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
      use Phoenix.HTML
    end
  end

  # Functions defined here are available to all other views/templates
end
```

Besides bringing in all the functions and aliases available to `Phoenix.View`, the first line allows us to set the root directory within which Phoenix will look for templates. By default, that is `web/templates`. If we need to change that, this is the place to do so.

The `using/1` macro bundles together all the `use`, `import`, and `alias` statements the main view module needs in one place. We can add others we might need here to augment the defaults. Once there, they will be available in the rest of the main view module as well as in any other view modules that use it.

Finally, as the comment at the bottom of the file states, we can define any functions we might need in views or templates across the application. Here's a simple example.

```elixir
defmodule HelloPhoenix.View do
  . . .

  # Functions defined here are available to all other views/templates
  def title do
    "Awesome New Title!"
  end
end
```

Let's open up our application layout template, `templates/layout/application.html.eex`, and change this line,
```html
<title>Hello Phoenix!</title>
```

to look like this.

```elixir
<title><%= title %></title>
```
When we reload the Welcome to Phoenix page, we should see our new title.

The `<%=` and `%>` are from the Elixir [Eex](http://elixir-lang.org/docs/stable/eex/) project. They enclose executable Elixir code within a template. The `=` tells Eex to print the result. If the `=` is not there, Eex wills still execute the code, but there will be no output. In our example, we are calling the `title` function from `HelloPhoenix.View` and printing the output into the title tag.

Note that we didn't need to fully qualify the `title` function with `HelloPhoenix.View`. Our layout template has a layout view to render it, and the layout view uses `HelloPhoenix.View`.

```elixir
defmodule HelloPhoenix.LayoutView do
  use HelloPhoenix.View

end
```

The main view provides other conveniences. Since we have `import HelloPhoenix.Router.Helpers` in the `using do` block, we don't have to fully qualify path helpers in templates. Let's see how that works by changing the template for our Welcome to Phoenix page.

Open up the `templates/page/index.html.eex` in your favorite text editor and locate this stanza.

```html
<div class="jumbotron">
  <h2>Welcome to Phoenix!</h2>
  <p class="lead">Phoenix is an Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality.</p>
</div>
```

Then add a line with a link back to the same page. (The object is to see how path helpers respond in a template, not to add any functionality.)
```html
<div class="jumbotron">
  <h2>Welcome to Phoenix!</h2>
  <p class="lead">Phoenix is an Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality.</p>
  <p><a href="<%= page_path @conn, :index %>">Link back to ourselves</a></p>
</div>
```

Let's reload the page and view source to see what we have.

```html
<a href="/">Link back to ourselves</a>
```

Great, `page_path/2` evaluated to `/` as we would expect, and we didn't need to qualify it with `HelloPhoenix.View`.

###Individual Views

Individual views have a much narrower scope. Their job is to render, and provide decorating functions for a single directory of templates. Phoenix assumes a strong naming convention from controllers to views to the templates they render. The `PageController` requires a `PageView` to render templates in the `web/templates/page` directory. If we change the `:root` declaration in the main view, of course, Phoenix would look for a `page` directory within the directory we set there.

You might be wondering how individual views are able to work so closely with templates.

The main view uses Phoenix's main template module with `use Phoenix.Template`. `Phoenix.Template` provides many convenience methods for working with templates - finding them, extracting their names and paths, and much more.

Let's experiment a little with one of the generated views Phoenix provides us, `web/views/page_view.ex`. We'll add a `message` function to it, like this.

```elixir
defmodule HelloPhoenix.PageView do
  use HelloPhoenix.View

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
{:safe, "This is the message: Hello from the view!\n"}
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
 "I came from assigns: Assigns has an @.\nThis is the message: Hello from the view!\n"}
 ```
Let's test out the HTML escaping, just for fun.

```console
iex(6)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", message: "<script>badThings();</script>")
{:safe,
 "I came from assigns: &lt;script&gt;badThings();&lt;/script&gt;\nThis is the message: Hello from the view!\n"}
```
If we need only the rendered string, without the whole tuple, we can use the `render_to_iodata/3`.

 ```console
 iex(3)> Phoenix.View.render_to_iodata(HelloPhoenix.PageView, "test.html", message: "Assigns has an @.")
"I came from assigns: Assigns has an @.\nThis is the message: Hello from the view!\n"
  ```

###A Word About Layouts

Layouts are just templates. They have an individual view, just like other templates. In a newly generated app, this is `web/views/layout_view.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question!

When a template is rendered, the layout view will assign `@inner` with the rendered contents of the template. For HTML templates, `@inner` will be always marked as safe.

If we look at `web/templates/layout/application.html.eex`, just about in the middle of the `<body>`, we will see this.

```html
<%= @inner %>
```
This is where the rendered string from the template will be placed.

###The ErrorView

Phoenix recently added a new individual view to every generated application, the `ErrorView` which lives here `web/views/error_view.ex`. The purpose of the `ErrorView` is to handle two of the most common errors - `404 not found` and `500 internal error` - in a general way, from one centralized location. Let's see what it looks like.

```elixir
defmodule HelloPhoenix.ErrorView do
  use HelloPhoenix.View

  def render("404.html", _assigns) do
    "Page not found - 404"
  end

  def render("500.html", _assigns) do
    "Server internal error - 500"
  end

  # Render all other templates as 500
  def render(_, assigns) do
    render "500.html", assigns
  end
end
```
Before we dive into this, let's see what the rendered `404 not found` message looks like in a browser. In the development environment, Phoenix will debug errors by default, showing us a very informative debugging page. What we want here, however, is to see what page the application would serve in production. In order to do that we need to change some configuration in `config/dev.exs`. We change `debug_errors: false` and add `catch_errors: true`.

```elixir
use Mix.Config

config :hello_phoenix, HelloPhoenix.Endpoint,
http: [port: System.get_env("PORT") || 4000],
debug_errors: false,
catch_errors: true,
cache_static_lookup: false
. . .
```

Now let's go to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) for a running local application and see what we get.

Ok, that's not very exciting. We get the bare string "Page not found - 404", displayed without a layout.

Let's see if we can use what we already know about views to make this a more interesting error page.

The first question is, where does that error string come from? The answer is right in the `ErrorView`.

```elixir
def render("404.html", _assigns) do
  "Page not found - 404"
end
```
Great, so we have a `render/2` function that takes a template and an `assigns` map, which we ignore. Where is this `render/2` function being called from?

The answer is the `render/4` function defined in the `Phoenix.Endpoint.ErrorHandler` module. The whole purpose of this module is to catch errors and render them with a view, in our case, the `HelloPhoenix.ErrorView`.

The `Endpoint.ErrorHandler` has determined that our request with the silly path has led to a `404 not found` error. Our request is rendered through the `:browser` pipeline, meaning our format is `HTML`. This makes the `ErrorHandler` try to render a template called "404.html". That, in turn makes this clause of `render/2` match.

Now that we understand how we got here, let's make a better error page.

If we look in the `web/templates/page` directory, we'll see two templates which are unused in a new application, `not_found.html.eex` and `error.html.eex`. We can make use of these now.

First, let's add a little markup to our `not_found.html.eex` template, changing it from this:

```
The page you are looking for does not exist
```
to this:

```html
<div class="jumbotron">
  <p>Sorry, the page you are looking for does not exist.</p>
</div>
```
Now we can use the `render/3` function we saw above when we were experimenting with rendering in the `iex` session.

Our `render/2` function should look like this when we've modified it.

```elixir
def render("404.html", _assigns) do
  render(HelloPhoenix.PageView, "not_found.html", %{})
end
```
Let's go back to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) and see what that looks like.

We've made progress; we're rendering our new template, complete with markup. We still don't have a layout, though.

In order to make that happen, we need to specify a layout, but where? It turns out that the `assigns` map - the one we passed as an empty map for our third argument just now - can have a `:layout` key and a two element tuple as a value. The tuple consists of the layout view as the first element, and the layout template as the second. Let's try passing that in as our third argument to `render/3`.

```elixir
def render("404.html", _assigns) do
  render(HelloPhoenix.PageView, "not_found.html", layout: {HelloPhoenix.LayoutView, "application.html"})
end
```
Now when we go back to [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path), we should see exactly what we're looking for, our new template rendered within the application layout.

Of course, we can do these same steps with the `def render("500.html", _assigns) do` clause in our `ErrorView` and the `error.html.eex` template as well.

We can also use the `assigns` map passed into `render/2` in the `ErrorView` instead of discarding it. We can put the new layout key and value into it to display more information in our templates.
