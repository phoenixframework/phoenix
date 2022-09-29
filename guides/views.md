# Views and templates

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

The main job of a Phoenix view is to render the body of the response which gets sent back to browsers and to API clients. Most of the time, we use templates to build these responses, but we can also craft them by hand. We will learn how.

## Rendering templates

Phoenix assumes a strong naming convention from controllers to views to the templates they render. `PageController` requires a `PageView` to render templates in the `lib/hello_web/templates/page/` directory. While all of these can be customizable (see `Phoenix.View` and `Phoenix.Template` for more information), we recommend users stick with Phoenix' convention.

A newly generated Phoenix application has three view modules - `ErrorView`, `LayoutView`, and `PageView` -  which are all in the `lib/hello_web/views/` directory.

Let's take a quick look at `LayoutView`.

```elixir
defmodule HelloWeb.LayoutView do
  use HelloWeb, :view
end
```

That's simple enough. There's only one line, `use HelloWeb, :view`. This line calls the `view/0` function defined in `HelloWeb` which sets up the basic imports and configuration for our views and templates.

All of the imports and aliases we make in our view will also be available in our templates. That's because templates are effectively compiled into functions inside their respective views. For example, if you define a function in your view, you will be able to invoke it directly from the template. Let's see this in practice.

Open up our application layout template, `lib/hello_web/templates/layout/root.html.heex`, and change this line,

```heex
<%= live_title_tag assigns[:page_title] || "Hello", suffix: " · Phoenix Framework" %>
```

to call a `title/0` function, like this.

```heex
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

Our layouts and templates use the `.heex` extension, which stands for  "HTML+EEx". EEx is an Elixir library that uses `<%= expression %>` to execute Elixir expressions and interpolate their results into the template. This is frequently used to display assigns we have set by way of the `@` shortcut. In your controller, if you invoke:

```elixir
  render(conn, "show.html", username: "joe")
```

Then you can access said username in the templates as `<%= @username %>`. In addition to displaying assigns and functions, we can use pretty much any Elixir expression. For example, in order to have conditionals:

```heex
<%= if some_condition? do %>
  <p>Some condition is true for user: <%= @username %></p>
<% else %>
  <p>Some condition is false for user: <%= @username %></p>
<% end %>
```

or even loops:

```heex
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

Did you notice the use of `<%= %>` versus `<% %>` above? All expressions that output something to the template **must** use the equals sign (`=`). If this is not included the code will still be executed but nothing will be inserted into the template.

HEEx also comes with handy HTML extensions we will learn next.

### HTML extensions

Besides allowing interpolation of Elixir expressions via `<%= %>`, `.heex` templates come with HTML-aware extensions. For example, let's see what happens if you try to interpolate a value with "<" or ">" in it, which would lead to HTML injection:

```heex
<%= "<b>Bold?</b>" %>
```

Once you render the template, you will see the literal `<b>` on the page. This means users cannot inject HTML content on the page. If you want to allow them to do so, you can call `raw`, but do so with extreme care:

```heex
<%= raw "<b>Bold?</b>" %>
```

Another super power of HEEx templates is validation of HTML and lean interpolation syntax of attributes. You can write:

```heex
<div title="My div" class={@class}>
  <p>Hello <%= @username %></p>
</div>
```

Notice how you could simply use `key={value}`. HEEx will automatically handle special values such as `false` to remove the attribute or a list of classes.

To interpolate a dynamic number of attributes in a keyword list or map, do:

```heex
<div title="My div" {@many_attributes}>
  <p>Hello <%= @username %></p>
</div>
```

Also, try removing the closing `</div>` or renaming it to `</div-typo>`. HEEx templates will let you know about your error.

### HTML components

The last feature provided by HEEx is the idea of components. Components are pure functions that can be either local (same module) or remote (external module).

HEEx allows invoking those function components directly in the template using an HTML-like notation. For example, a remote function:

```heex
<MyApp.Weather.city name="Kraków"/>
```

A local function can be invoked with a leading dot:

```heex
<.city name="Kraków"/>
```

where the component could be defined as follows:

```elixir
defmodule MyApp.Weather do
  use Phoenix.Component

  def city(assigns) do
    ~H"""
    The chosen city is: <%= @name %>.
    """
  end

  def country(assigns) do
    ~H"""
    The chosen country is: <%= @name %>.
    """
  end
end
```

In the example above, we used the `~H` sigil syntax to embed HEEx templates directly into our modules. We have already invoked the `city` component and calling the `country` component wouldn't be different:

```heex
<div title="My div" {@many_attributes}>
  <p>Hello <%= @username %></p>
  <MyApp.Weather.country name="Brazil" />
</div>
```

You can learn more about components in [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html).

### Understanding template compilation

Phoenix templates are compiled into Elixir code, which make them extremely performant. Let's learn more about this.

When a template is compiled into a view, it is simply compiled as a `render/2` function that expects two arguments: the template name and the assigns.

You can prove this by temporarily adding this function clause to your `PageView` module in `lib/hello_web/views/page_view.ex`.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def render("index.html", assigns) do
    "rendering with assigns #{inspect Map.keys(assigns)}"
  end
end
```

Now if you fire up the server with `mix phx.server` and visit [`http://localhost:4000`](http://localhost:4000), you should see the following text below your layout header instead of the main template page:

```console
rendering with assigns [:conn]
```

By defining our own clause in `render/2`, it takes higher priority than the template, but the template is still there, which you can verify by simply removing the newly added clause.

Pretty neat, right? At compile-time, Phoenix precompiles all `*.html.heex` templates and turns them into `render/2` function clauses on their respective view modules. At runtime, all templates are already loaded in memory. There's no disk reads, complex file caching, or template engine computation involved.

### Manually rendering templates

So far, Phoenix has taken care of putting everything in place and rendering views for us. However, we can also render views directly.

Let's create a new template to play around with, `lib/hello_web/templates/page/test.html.heex`:

```heex
This is the message: <%= @message %>
```

This doesn't correspond to any action in our controller, which is fine. We'll exercise it in an `IEx` session. At the root of our project, we can run `iex -S mix`, and then explicitly render our template. Let's give it a try by calling `Phoenix.View.render/3` with the view name, the template name, and a set of assigns we might have wanted to pass and we got the rendered template as a string:

```elixir
iex(1)> Phoenix.View.render(HelloWeb.PageView, "test.html", message: "Hello from IEx!")
%Phoenix.LiveView.Rendered{
  dynamic: #Function<1.71437968/1 in Hello16Web.PageView."test.html"/1>,
  fingerprint: 142353463236917710626026938006893093300,
  root: false,
  static: ["This is the message: ", ""]
}
```

The output we got above is not very helpful. That's the internal representation of how Phoenix keeps our rendered templates. Luckily, we can convert them into strings with `render_to_string/3`:

```elixir
iex(2)> Phoenix.View.render_to_string(HelloWeb.PageView, "test.html", message: "Hello from IEx!")
"This is the message: Hello from IEx!"
```

That's much better! Let's test out the HTML escaping, just for fun:

```elixir
iex(3)> Phoenix.View.render_to_string(HelloWeb.PageView, "test.html", message: "<script>badThings();</script>")
"This is the message: &lt;script&gt;badThings();&lt;/script&gt;"
```

## Sharing views and templates

Now that we have acquainted ourselves with `Phoenix.View.render/3`, we are ready to share views and templates from inside other views and templates. We use `render/3` to compose our templates and at the end Phoenix will convert them all into the proper representation to send to the browser.

For example, if you want to render the `test.html` template from inside our layout, you can invoke [`render/3`] directly from the layout `lib/hello_web/templates/layout/root.html.heex`:

```heex
<%= Phoenix.View.render(HelloWeb.PageView, "test.html", message: "Hello from layout!") %>
```

If you visit the [welcome page], you should see the message from the layout.

Since `Phoenix.View` is automatically imported into our templates, we could even skip the `Phoenix.View` module name and simply invoke `render(...)` directly:

```heex
<%= render(HelloWeb.PageView, "test.html", message: "Hello from layout!") %>
```

If you want to render a template within the same view, you can skip the view name, and simply call `render("test.html", message: "Hello from sibling template!")` instead. For example, open up `lib/hello_web/templates/page/index.html.heex` and add this at the top:

```heex
<%= render("test.html", message: "Hello from sibling template!") %>
```

Now if you visit the Welcome page, you see the template results also shown.

## Layouts

Layouts are just templates. They have a view, just like other templates. In a newly generated app, this is `lib/hello_web/views/layout_view.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question! If we look at `lib/hello_web/templates/layout/root.html.heex`, just about at the end of the `<body>`, we will see this.

```heex
<%= @inner_content %>
```

In other words, the inner template is placed in the `@inner_content` assign.

## Rendering JSON

The view's job is not only to render HTML templates. Views are about data presentation. Given a bag of data, the view's purpose is to present that in a meaningful way given some format, be it HTML, JSON, CSV, or others. Many web apps today return JSON to remote clients, and Phoenix views are *great* for JSON rendering.

Phoenix uses the `Jason` library to encode JSON, so all we need to do in our views is to format the data we would like to respond with as a list or a map, and Phoenix will do the rest.

While it is possible to respond with JSON back directly from the controller and skip the view, Phoenix views provide a much more structured approach for doing  so. Let's take our `PageController`, and see what it may look like when we respond with some static page maps as JSON, instead of HTML.

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

Here, we have our `show/2` and `index/2` actions returning static page data. Instead of passing in `"show.html"` to [`render/3`] as the template name, we pass `"show.json"`. This way, we can have views that are responsible for rendering HTML as well as JSON by pattern matching on different file types.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def render("index.json", %{pages: pages}) do
    %{data: Enum.map(pages, fn page -> %{title: page.title} end)}
  end

  def render("show.json", %{page: page}) do
    %{data: %{title: page.title}}
  end
end
```

In the view we see our `render/2` function pattern matching on `"index.json"`, `"show.json"`, and `"page.json"`. The `"index.json"` and `"show.json"` are the ones requested directly from the controller. They also match on the assigns sent by the controller. Phoenix understands the `.json` extension and will take care of converting the data-structures we return into JSON.  `"index.json"` will respond like this:

```json
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

And `"show.json"` like this:

```json
{
  "data": {
    "title": "foo"
  }
}
```

However, there is some duplication between `index.json` and `show.json`, as both encode the same logic on how to render pages. We can address this by moving the page rendering to a separate function clause and using `render_many/3` and `render_one/3` to reuse it:

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

The [`render_many/3`] function takes the data we want to respond with (`pages`), a view, and a string to pattern match on the `render/2` function defined on view. It will map over each item in `pages` and call `PageView.render("page.json", %{page: page})`. [`render_one/3`] follows the same signature, ultimately using the `render/2` matching `page.json` to specify what each `page` looks like.

It's useful to build our views like this so that they are composable. Imagine a situation where our `Page` has a `has_many` relationship (#NOTE: We haven't talked about has_many relationship yet#) with `Author`, and depending on the request, we may want to send back `author` data with the `page`. We can easily accomplish this with a new `render/2`:

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

The name used in assigns is determined from the view. For example `PageView` will use `%{page: page}` and `AuthorView` will use `%{author: author}`. This can be overridden with the `as` option. Let's assume that the author view uses `%{writer: writer}` instead of `%{author: author}`:

```elixir
def render("page_with_authors.json", %{page: page}) do
  %{title: page.title,
    authors: render_many(page.authors, AuthorView, "author.json", as: :writer)}
end
```

## Error pages

Phoenix has a view called `ErrorView` which lives in `lib/hello_web/views/error_view.ex`. The purpose of `ErrorView` is to handle errors in a general way, from one centralized location.  Similar to the views we built in this guide, error views can return both HTML and JSON responses. See the [Custom Error Pages How-To](custom_error_pages.html) for more information.

[welcome page]: http://localhost:4000
[`render/3`]: `Phoenix.View.render/3`
[`render_many/3`]: `Phoenix.View.render_many/3`
[`render_one/3`]: `Phoenix.View.render_one/3`
[`render_to_string/3`]: `Phoenix.View.render_to_string/3`
