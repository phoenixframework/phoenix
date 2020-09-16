# Views and templates

> **Requirement**: This guide expects that you have gone through the introductory guides and got a Phoenix application up and running.

> **Requirement**: This guide expects that you have gone through [the Request life-cycle guide](request_lifecycle.html).

Phoenix views main job is to render the body of the responses to be sent back to browsers and API clients. Most of the time, we use templates to build said responses, but we can also craft them by hand. We will learn how.

## Rendering Templates

Phoenix assumes a strong naming convention from controllers to views to the templates they render. The `PageController` requires a `PageView` to render templates in the `lib/hello_web/templates/page` directory. While all of these can be customizable (see `Phoenix.View` and `Phoenix.Template` for more information), we recommend users stick with Phoenix' convention.

A newly generated Phoenix application has three view modules - `ErrorView`, `LayoutView`, and `PageView` -  which are all in the, `lib/hello_web/views` directory.

Let's take a quick look at the `LayoutView`.

```elixir
defmodule HelloWeb.LayoutView do
  use HelloWeb, :view
end
```

That's simple enough. There's only one line, `use HelloWeb, :view`. This line calls the `view/0` function we just saw above. Besides allowing us to change our template root, `view/0` exercises the `__using__` macro in the `Phoenix.View` module. It also handles any module imports or aliases our application's view modules might need.

All of the imports and aliases we make in our view will also be available in our templates. That's because templates are effectively compiled into functions inside their respective views. For example, if you define a function in your view, you will be able to invoke it directly from the template. Let's see this in practice.

Open up our application layout template, `lib/hello_web/templates/layout/app.html.eex`, and change this line,

```html
<title>Hello · Phoenix Framework</title>
```

to call a `title/0` function, like this.

```html
<title><%= title() %></title>
```

Now let's add a `title/0` function to our `LayoutView`.

```elixir
defmodule HelloWeb.LayoutView do
  use HelloWeb, :view

  def title() do
    "Awesome New Title!"
  end
end
```

When we reload our home page, we should see our new title. Since templates are compiled inside the view, we could invoke the view function simply as `title()`, otherwise we would have to type `HelloWeb.LayoutView.title()`.

As you may recall, Elixir templates use Embedded Elixir, known as `EEx`. We use `<%= expression %>` to execute Elixir expressions. The result of the expression is interpolated into the template. You can use pretty much any Elixir expression. For example, in order to have conditionals:

```html
<%= if some_condition? do %>
  <p>Some condition is true for user: <%= @user.name %></p>
<% else %>
  <p>Some condition is false for user: <%= @user.name %></p>
<% end %>
```

or even loops:

```html
<table>
  <tr>
    <th>Number</th>
    <th>Power</th>
  </tr>
<%= for number <- 1..10 do %>
  <tr>
    <td><%= number %></td>
    <td><%= number * number %></td>
  </tr>
<% end %>
</table>
```

At the end of the day, our templates are always compiled into Elixir code. Let's learn more about this.

### Understanding template compilation

When a template is compiled into a view, it is simply compiled as a `render` function that expects two arguments: the template name and the assigns.

You can prove this by temporarily adding this function clause to your `PageView` module in `lib/hello_web/views/page_view.ex`.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def render("index.html", assigns) do
    "rendering with assigns #{inspect Map.keys(assigns)}"
  end
end
```

Now if you fire up the server with `mix phx.server` and visit `http://localhost:4000`, you should see the following text below your layout header instead of the main template page:

```console
rendering with assigns [:conn]
```

By defining our own clause in `render`, it takes higher priority than the template, but the template is still there, which you can verify by simply removing the newly added clause.

Pretty neat, right? At compile-time, Phoenix precompiles all `*.html.eex` templates and turns them into `render/2` function clauses on their respective view modules. At runtime, all templates are already loaded in memory. There's no disk reads, complex file caching, or template engine computation involved.

### Manually rendering templates

So far, Phoenix has taken care of putting everything in place and rendering views for us. However, we can also render views directly.

Let's create a new template to play around with, `lib/hello_web/templates/page/test.html.eex`:

```html
This is the message: <%= @message %>
```

This doesn't correspond to any action in our controller, which is fine. We'll exercise it in an `iex` session. At the root of our project, we can run `iex -S mix`, and then explicitly render our template.

```elixir
iex(1)> Phoenix.View.render(HelloWeb.PageView, "test.html", message: "Hello from IEx!")
{:safe, ["This is the message: ", "Hello from IEx!"]}
```

As we can see, we're calling `render/3` with the individual view responsible for our test template, the name of our test template, and a set of assigns we might have wanted to pass in. The return value is a tuple beginning with the atom `:safe` and the resultant io list of the interpolated template. "Safe" here means that Phoenix has escaped the contents of our rendered template to avoid XSS injection attacks.

Let's test out the HTML escaping, just for fun:

```elixir
iex(2)> Phoenix.View.render(HelloWeb.PageView, "test.html", message: "<script>badThings();</script>")
{:safe, ["This is the message: ", "&lt;script&gt;badThings();&lt;/script&gt;"]}
```

If we need only the rendered string, without the whole tuple, we can use `render_to_string/3`.

```elixir
iex(5)> Phoenix.View.render_to_string(HelloWeb.PageView, "test.html", message: "Hello from IEx!")
"This is the message: Hello from IEx!"
```

## Sharing views and templates

Now that we have acquainted ourselves with `Phoenix.View.render/3`, we are ready to share views and templates from inside other views and templates.

For example, if you want to render the "test.html" template from inside our layout, you can invoke `render/3` directly from the layout:

```html
<%= Phoenix.View.render(HelloWeb.PageView, "test.html", message: "Hello from layout!") %>
```

If you visit the Welcome page, you should see the message from the layout.

Since `Phoenix.View` is automatically imported into our templates, we could even skip the `Phoenix.View` module name and simply invoke `render(...)` directly:

```html
<%= render(HelloWeb.PageView, "test.html", message: "Hello from layout!") %>
```

If you want to render a template within the same view, you can skip the view name, and simply call `render("test.html", message: "Hello from sibling template!")` instead. For example, open up `lib/hello_web/templates/page/index.html.eex` and add this at the top:

```html
<%= render("test.html", message: "Hello from sibling template!") %>
```

Now if you visit the Welcome page, you see the template results also shown.

## Layouts

Layouts are just templates. They have a view, just like other templates. In a newly generated app, this is `lib/hello_web/views/layout_view.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question! If we look at `lib/hello_web/templates/layout/app.html.eex`, just about in the middle of the `<body>`, we will see this.

```html
<%= @inner_content %>
```

In other words, the inner template is placed in the `@inner_content` assign.

## Rendering JSON

The view's job is not only to render HTML templates. Views are about data presentation. Given a bag of data, the view's purpose is to present that in a meaningful way given some format, be it HTML, JSON, CSV, or others. Many web apps today return JSON to remote clients, and Phoenix Views are *great* for JSON rendering.

Phoenix uses [Jason](https://github.com/michalmuskala/jason) to encode JSON, so all we need to do in our views is format the data we'd like to respond with as a list or a map, and Phoenix will do the rest.

While it is possible to respond with JSON back directly from the controller and skip the view, Phoenix Views provide a much more structured approach for doing  so. Let's take our `PageController`, and see what it might look like when we respond with some static page maps as JSON, instead of HTML.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def show(conn, _params) do
    page = %{title: "foo"}

    render(conn, "show.json", page: page)
  end

  def index(conn, _params) do
    pages = [%{title: "foo"}, %{title: "bar"}]

    render(conn, "index.json", pages: pages)
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

In the view we see our `render/2` function pattern matching on `"index.json"`, `"show.json"`, and `"page.json"`. The "index.json" and "show.json" are the ones requested directly from the controller. They also match on the assigns sent by the controller. `"index.json"` will respond with JSON like this:

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

And the `render/2` matching `"show.json"`:

```javascript
{
  "data": {
    "title": "foo"
  }
}
```

This works because both "index.json" and "show.json" builds themselves on top of an internal "page.json" clause.

The `render_many/3` function takes the data we want to respond with (`pages`), a view, and a string to pattern match on the `render/2` function defined on view. It will map over each item in `pages`, and call `PageView.render("page.json", %{page: page})`. `render_one/3` follows, the same signature, ultimately using the `render/2` matching `page.json` to specify what each `page` looks like.

It's useful to build our views like this so they can be composable. Imagine a situation where our `Page` has a `has_many` relationship with `Author`, and depending on the request, we may want to send back `author` data with the `page`. We can easily accomplish this with a new `render/2`:

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

## Error pages

Phoenix has a view called the `ErrorView` which lives in `lib/hello_web/views/error_view.ex`. The purpose of the `ErrorView` is to handle errors in a general way, from one centralized location.  Similar to the views we built in this guide, error views can return both HTML and JSON responses. See [the Custom Error Pages How-To](custom_error_pages.html) for more information.
