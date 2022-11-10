# Components and HEEx Templates

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

The Phoenix endpoint pipeline takes a request, routes it with a router to a controller, and calls a view module to render a template. The view interface from the controller is simple – the controller calls a view function with the connections assigns, and the functions job is to return a HEEx template. We call functions that accept assigns and return HEEx, *function components*, which are provided by the `Phoenix.Component` module.

Function components allow you to define reusable components in your application for building up your user interfaces. A function component is any function that receives an assigns map as an argument and returns
a rendered struct built with [the `~H` sigil](`Phoenix.Component.sigil_H/2`):

```elixir
defmodule MyComponent do
  use Phoenix.Component

  def greet(assigns) do
    ~H"""
    <p>Hello, <%= @name %>!</p>
    """
  end
end
```

Functions components can also be defined in `.heex` files by using `Phoenix.Component.embed_templates/2`:

```elixir
defmodule MyComponent do
  use Phoenix.Component

  # embed all .heex templates in current directory, such as "greet.html.heex"
  embed_templates "*"
end
```

Function components are the essential building block for any kind of markup-based template rendering you'll perform in Phoenix. They served a shared abstraction for the standard MVC controller-based applications, LiveView applications, and smaller UI definition you'll use throughout other templates.

We'll cover function components and HEEx in detail in a moment, but first let's learn how templates are rendered from the endpoint pipeline.

## Rendering templates from the controller

Phoenix assumes a strong naming convention from controllers to views to the templates they render. `PageController` requires a `PageHTML` to render templates in the `lib/hello_web/controllers/page_html/` directory. While all of these can be customizable (see `Phoenix.Component.embed_templates/2` and `Phoenix.Template` for more information), we recommend users stick with Phoenix' convention.

A newly generated Phoenix application has two view modules - `HelloWeb.ErrorHTML` and `HelloWeb.PageHTML`, which are collocated by the controller in `lib/hello_web/controllers`. Phoenix also includes a `lib/hello_web/components` directory which holds all your shared HEEx function components for the application. Out of the box, a `HelloWeb.Layouts` module is defined at `lib/hello_web/components/layouts.ex`, which defines application layouts, and a `HelloWeb.CoreComponents` module at `lib/hello_web/components/core_components.ex` holds a base set of UI components such as forms, buttons, and modals which are used by the `phx.gen.*` generators and provide a bootstrapped core component building blocks.


Let's take a quick look at `HelloWeb.Layouts`.

```elixir
defmodule HelloWeb.Layouts do
  use HelloWeb, :html

  embed_templates "layouts/*"
end
```

That's simple enough. There's only two lines, `use HelloWeb, :html`. This line calls the `html/0` function defined in `HelloWeb` which sets up the basic imports and configuration for our function components and templates.

All of the imports and aliases we make in our module will also be available in our templates. That's because templates are effectively compiled into functions inside their respective module. For example, if you define a function in your module, you will be able to invoke it directly from the template. Let's see this in practice.

Open up our application layout template, `lib/hello_web/components/layouts/root.html.heex`, and change this line,

```heex
<.live_title suffix=" · Phoenix Framework">
  <%= assigns[:page_title] || "Hello" %>
</.live_title>
```

to call a `title/1` function, like this.

```heex
<.title suffix=" · Phoenix Framework" />
```

Now let's add a `title/1` function to our `Layouts` module:

```elixir
defmodule HelloWeb.Layouts do
  use HelloWeb, :html

  embed_templates "layouts/*"

  attr :suffix, :string, default: nil

  def title(assigns) do
    ~H"""
    Welcome to HelloWeb! <%= @suffix %>
    """
  end
end
```

We declared the attributes we accept via `attr` provided by `Phoenix.Component`, then we defined our `title/1` function which returns the HEEx template. When we reload our home page, we should see our new title. Since templates are compiled inside the view, we can invoke the view function simply as `<.title suffix="..." />`, but we can also type `<HelloWeb.LayoutView.title suffix="..." />` if the component was defined elsewhere.

Our layouts and templates use the `.heex` extension, which stands for  "HTML+EEx". EEx is an Elixir library that uses `<%= expression %>` to execute Elixir expressions and interpolate their results into the template. This is frequently used to display assigns we have set by way of the `@` shortcut. In your controller, if you invoke:

```elixir
  render(conn, :show, username: "joe")
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

HEEx also supports shorthand syntax for `if` and `for` expressions via the special `:if` and `:for` attributes. For example, rather than this:

```heex
<%= if @some_condition do %>
  <div>...</div>
<% end %>
```

You can write:

```heex
<div :if={@some_condition}>...</div>
```

Likewise, for comprehensions may be written as:

```heex
<ul>
  <li :for={item <- @items}><%= item.name %></li>
</ul>
```

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

You can prove this by temporarily adding this function clause to your `PageHTML` module in `lib/hello_web/controllers/page_html.ex`.

```elixir
defmodule HelloWeb.PageHTML do
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

This doesn't correspond to any action in our controller, which is fine. We'll exercise it in an `IEx` session. At the root of our project, we can run `iex -S mix`, and then explicitly render our template. Let's give it a try by calling `Phoenix.Template.render/4` with the view name, the template name, format, and a set of assigns we might have wanted to pass and we got the rendered template as a string:

```elixir
iex(1)> Phoenix.Template.render(HelloWeb.PageHTML, "test", "html", message: "Hello from IEx!")
%Phoenix.LiveView.Rendered{
  dynamic: #Function<1.71437968/1 in Hello16Web.PageHTML."test.html"/1>,
  fingerprint: 142353463236917710626026938006893093300,
  root: false,
  static: ["This is the message: ", ""]
}
```

The output we got above is not very helpful. That's the internal representation of how Phoenix keeps our rendered templates. Luckily, we can convert them into strings with `render_to_string/3`:

```elixir
iex(2)> Phoenix.Template.render_to_string(HelloWeb.PageHTML, "test", "html", message: "Hello from IEx!")
"This is the message: Hello from IEx!"
```

That's much better! Let's test out the HTML escaping, just for fun:

```elixir
iex(3)> Phoenix.Template.render_to_string(HelloWeb.PageHTML, "test", "html", message: "<script>badThings();</script>")
"This is the message: &lt;script&gt;badThings();&lt;/script&gt;"
```

## Layouts

Layouts are just function components. They are defined in a module, just like all other function component templates. In a newly generated app, this is `lib/hello_web/components/layouts.ex`. You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question! If we look at `lib/hello_web/components/layouts/root.html.heex`, just about at the end of the `<body>`, we will see this.

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

    render(conn, :show, page: page)
  end

  def index(conn, _params) do
    pages = [%{title: "foo"}, %{title: "bar"}]

    render(conn, :index, pages: pages)
  end
end
```
Here we are calling `render` with a `:show` or `:index` template. We can have the show and index actions fetch the same data but render different formats by defining a view specific to HTML or JSON. By default, Phoenix applications specify the `:html`, and `:json` formats when calling `use Phoenix.Controller` in your `lib/hello_web.ex` file. This will look for a `PageHTML` and `PageJSON` view module when a request comes into `PageController`. These can be overridden by calling `put_view` directly and specify the view modules per format:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  plug :put_view, html: HelloWeb.PageHTML, json: HelloWeb.PageJSON
end
```

For JSON support, we simply define a `PageJSON` module and template functions, just like our HTML templates except this time we'll return a map to be serialized as JSON:

```elixir
defmodule HelloWeb.PageJSON do

  def index(%{pages: pages}) do
    %{data: Enum.map(pages, fn page -> %{title: page.title} end)}
  end

  def show(%{page: page}) do
    %{data: %{title: page.title}}
  end
end
```

Just like HTML function components, our JSON functions receive assigns from the controller, and here can match on the assigns passed in. Phoenix handles content negotiation and will take care of converting the data-structures we return into JSON. A JSON request to the index action will respond like this:

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

And the show action like this:

```json
{
  "data": {
    "title": "foo"
  }
}
```

## Error pages

Phoenix has two views called `ErrorHTML` and `ErrorJSON` which live in `lib/hello_web/controllers/`. The purpose of these views is to handle errors in a general way for incoming HTML or JSON requests. Similar to the views we built in this guide, error views can return both HTML and JSON responses. See the [Custom Error Pages How-To](custom_error_pages.html) for more information.

[welcome page]: http://localhost:4000
[`render/4`]: `Phoenix.Template.render/4`
