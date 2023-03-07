# Components and HEEx

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

The Phoenix endpoint pipeline takes a request, routes it to a controller, and calls a view module to render a template. The view interface from the controller is simple – the controller calls a view function with the connections assigns, and the functions job is to return a HEEx template. We call any function that accepts an `assigns` parameter and returns a HEEx template to be a *function component*. Function components are defined with the help of the [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) module.

Function components are the essential building block for any kind of markup-based template rendering you'll perform in Phoenix. They serve as a shared abstraction for the standard MVC controller-based applications, LiveView applications, layouts, and smaller UI definitions you'll use throughout other templates.

In this chapter, we will recap how components were used in previous chapters and find new use cases for them.

## Function components

At the end of the Request life-cycle chapter, we created a template at `lib/hello_web/controllers/hello_html/show.html.heex`, let's open it up:

```heex
<section>
  <h2>Hello World, from <%= @messenger %>!</h2>
</section>
```

This template, is embedded as part of `HelloHTML`, at `lib/hello_web/controllers/hello_html.ex`:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"
end
```

That's simple enough. There's only two lines, `use HelloWeb, :html`. This line calls the `html/0` function defined in `HelloWeb` which sets up the basic imports and configuration for our function components and templates.

All of the imports and aliases we make in our module will also be available in our templates. That's because templates are effectively compiled into functions inside their respective module. For example, if you define a function in your module, you will be able to invoke it directly from the template. Let's see this in practice.

Imagine we want to refactor our `show.html.heex` to move the rendering of `<h2>Hello World, from <%= @messenger %>!</h2>` to its own function. We can move it to a function component inside `HelloHTML`, let's do so:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"

  attr :messenger, :string

  def greet(assigns) do
    ~H"""
    <h2>Hello World, from <%= @messenger %>!</h2>
    """
  end
end
```

In the example above, we defined a `greet/1` function which returns the HEEx template. Above the function, we called `attr`, provided by `Phoenix.Component`, which defines the attributes/assigns that function expects. Since templates are embedded inside the `HelloHTML` module, we can invoke the our component simply as `<.greet messenger="..." />`, but we can also type `<HelloWeb.HelloHTML.greet messenger="..." />` if the component was defined elsewhere.

By declaring attributes, Phoenix will warn if we call the `<.greet />` component without passing attributes. If an attribute is optional, you can specify the `:default` option with a value:

```
attr :messenger, :string, default: nil
```

Although this is a quick example, it shows the different roles function components play in Phoenix:

* Function components can be defined as functions that receive `assigns` as argument and call the `~H` sigil, as we did in `greet/1`

* Function components can be embedded from template files, that's how we load `show.html.heex` into `HelloWeb.HelloHTML`

* Function components can declare which attributes are expected, which are validated at compilation time

* Function components can be directly rendered from controllers

* Function components can be directly rendered from other function components, as we called `<.greet messenger={@messenger} />` from `show.html.heex`

And there's more. Before we go deeper, let's fully understand the expressive power behind the HEEx template language.

## HEEx

Function components and templates files are powered by [the HEEx template language](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2), which stands for  "HTML+EEx". EEx is an Elixir library that uses `<%= expression %>` to execute Elixir expressions and interpolate their results into the template. This is frequently used to display assigns we have set by way of the `@` shortcut. In your controller, if you invoke:

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

## Layouts

Layouts are just function components. They are defined in a module, just like all other function component templates. In a newly generated app, this is `lib/hello_web/components/layouts.ex`. You will also find in a `layouts` folder with the two built-in layouts generated by Phoenix. The default _root layout_ is called `root.html.heex`, and it is the layout into which all templates will be rendered by default. The second is the _app layout_, called `app.html.heex`, which is rendered within the root layout and includes our contents.

You may be wondering how the string resulting from a rendered view ends up inside a layout. That's a great question! If we look at `lib/hello_web/components/layouts/root.html.heex`, just about at the end of the `<body>`, we will see this.

```heex
<%= @inner_content %>
```

In other words, after rendering your page, the result is placed in the `@inner_content` assign.

Phoenix provides all kinds of conveniences to control which layout should be rendered. For example, the `Phoenix.Controller` module provides the `put_root_layout/2` function for us to switch _root layouts_. This takes `conn` as its first argument and a keyword list of formats and their layouts. You can set it to `false` to disable the layout altogether.

You can edit the `home` action of `PageController` in `lib/hello_web/controllers/page_controller.ex` to look like this.

```elixir
def home(conn, _params) do
  conn
  |> put_root_layout(html: false)
  |> render(:home)
end
```

After reloading [http://localhost:4000/](http://localhost:4000/), we should see a very different page, one with no title, logo image, or CSS styling at all.

To customize the application layout, we invoke a similar function named `put_layout/2`. Let's actually create another layout and render the index template into it. As an example, let's say we had a different layout for the admin section of our application which didn't have the logo image. To do this, copy the existing `app.html.heex` to a new file `admin.html.heex` in the same directory `lib/hello_web/components/layouts`. Then remove everything inside the `<header>...</header>` tags (or change it to whatever you desire) in the new file.

Now, in the `home` action of the controller of `lib/hello_web/controllers/page_controller.ex`, add the following:

```elixir
def home(conn, _params) do
  conn
  |> put_layout(html: :admin)
  |> render(:home)
end
```

When we load the page, we should be rendering the admin layout without the header (or a custom one that you wrote).

At this point, you may be wondering, why does Phoenix have two layouts?

First of all, it gives us flexibility. In practice, we will hardly have multiple root layouts, as they often contain only HTML headers. This allows us to focus on different application layouts with only the parts that changes between them. Second of all, Phoenix ships with a feature called LiveView, which allows us to build rich and real-time user experiences with server-rendered HTML. LiveView is capable of dynamically changing the contents of the page, but it only ever changes the app layout, never the root layout. We will learn about LiveView in future guides.

## CoreComponents

In a new Phoenix application, you will also find a `core_components.ex` module inside the `components` folder. This module is a great example of defining function components to be reused throughout our application. This guarantees that, as our application evolves, our components will look consistent.

If you look inside `def html` in `HelloWeb` placed at `lib/hello_web.ex`, you will see that `CoreComponents` are automatically imported into all HTML views via `use HelloWeb, :html`. This is also the reason why `CoreComponents` itself performs `use Phoenix.Component` instead `use HelloWeb, :html` at the top: doing the latter would cause a deadlock as we would try to import `CoreComponents` into itself.

CoreComponents also play an important role in Phoenix code generators, as the code generator assume those components are available in order to quickly scaffold your application. In case you want to learn more about all of these pieces, you may:

  * Exploring the generated `CoreComponents` module to learn more from practical examples

  * Read the official documentation for [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)

  * Read the official documentation for [HEEx and the ~H sigils](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2)
