# Components and HEEx

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

The Phoenix endpoint pipeline takes a request, routes it to a controller, and calls a view module to render a template. The view interface from the controller is simple – the controller calls a view function with the connection's assigns, and the function's job is to return a HEEx template. We call any function that accepts an `assigns` parameter and returns a HEEx template a *function component*.

> The Phoenix framework is designed for HTML applications, JSON APIs, GraphQL endpoints, etc. For this reason, all of the functionality related to HTML rendering comes as part of two separate packages:
>
> * [`phoenix_html`](https://hexdocs.pm/phoenix_html) - defines the building blocks for writing HTML safely. In your project, you'll interact primarily with the `Phoenix.HTML` module, which is imported by default in all templates
>
> * [`phoenix_live_view`](https://hexdocs.pm/phoenix_live_view) - a library for rich, real-time user experiences with server-rendered HTML. While LiveView provides several abstraction for building collaborative and dynamic applications, it also defines the `HEEx` template language, function components, and JS commands, which brings powerful abstractions for all kinds of server-rendered HTML applications

In this chapter, we will recap how components are used and dig deeper to discover new use cases.

## Function components

Function components are the essential building block for any kind of markup-based template rendering you'll perform in Phoenix. They serve as a shared abstraction for the standard MVC controller-based applications, LiveView applications, layouts, and smaller UI definitions you'll use throughout other templates. Their documentation is available in [the `Phoenix.Component` module](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html).

At the end of the Request life-cycle chapter, we created a template at `lib/hello_web/controllers/hello_html/show.html.heex`, let's open it up:

```heex
<Layouts.app flash={@flash}>
  <section>
    <h2>Hello World, from {@messenger}!</h2>
  </section>
</Layouts.app>
```

`<Layouts.app>` is a function component defined inside `lib/hello_web/components/layouts.ex`. If you open the file up, you will find:

```elixir
  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
    ...
```

So far, all of the function components we have defined also worked as templates. Let's learn more about them by defining our own component with the intent of encapsulating some HTML markup.

Imagine we want to refactor our `show.html.heex` to move the rendering of `<h2>Hello World, from {@messenger}!</h2>` to its own function. Remember that `show.html.heex` is embedded within the `HelloHTML` module. Let's open it up:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"
end
```

That's simple enough. There's only two lines, `use HelloWeb, :html`. This line calls the `html/0` function defined in `HelloWeb` which sets up the basic imports and configuration for our function components and templates. All of the imports and aliases in our module will also be available in our templates. Similarly, if we want to write a function component to be invoked from `show.html.heex`, we can simply add it to `HelloHTML`. Let's do so:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"

  attr :messenger, :string, required: true

  def greet(assigns) do
    ~H"""
    <h2>Hello World, from {@messenger}!</h2>
    """
  end
end
```

We declared the attributes we accept via the [`Phoenix.Component.attr/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#attr/3) macro, then we defined our `greet/1` function which returns the HEEx template.

Next we need to update `show.html.heex`:

```heex
<Layouts.app flash={@flash}>
  <section>
    <.greet messenger={@messenger} />
  </section>
</Layouts.app>
```

When we reload `http://localhost:4000/hello/Frank`, we should see the same content as before! The `show.html.heex` is now invoking two different function components:

  * `<Layouts.app` - the syntax for invoking function componente defined in a separate module and it follows the same rules as calling any other function in Elixir

  * `<.greet` - when the function component is defined in the same module as the template, we can skip the module name, and invoke the component using its name prefixed with a dot

Since the `show.html.heex` template is embedded within the `HelloHTML` module, we were able to invoke the function component directly as `<.greet messenger="..." />`. If the component was defined elsewhere, we would need to give its full name, such as: `<HelloWeb.HelloHTML.greet messenger="..." />`.

By declaring attributes as required, Phoenix will warn if we call the `<.greet />` component without passing attributes. If an attribute is optional, you can specify the `:default` option with a value:

```
attr :messenger, :string, default: nil
```

Overall, function components are the essential building block of Phoenix rendering stack. Next, let's fully understand the expressive power behind the HEEx template language.

## HEEx

Function components and templates files are powered by [the HEEx template language](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2), which stands for "HTML + Embedded Elixir". We can write Elixir code inside `{...}` for HTML-aware interpolation inside tag attributes and the body, as done above. For example, we use `@name` to access the key `name` defined inside `assigns`.

We can also interpolate arbitrary HEEx blocks using `<%= ... %>`. This is often used for block constructs. For example, in order to have conditionals:

```heex
<%= if some_condition? do %>
  <p>Some condition is true for user: {@messenger}</p>
<% else %>
  <p>Some condition is false for user: {@messenger}</p>
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
      <td>{number}</td>
      <td>{number * number}</td>
    </tr>
  <% end %>
</table>
```

HEEx also comes with handy HTML extensions we will learn next.

### HTML extensions

Besides allowing interpolation of Elixir expressions, `.heex` templates come with HTML-aware extensions. For example, let's see what happens if you try to interpolate a value with "<" or ">" in it, which would lead to HTML injection:

```heex
{"<b>Bold?</b>"}
```

Once you render the template, you will see the literal `<b>` on the page. This means users cannot inject HTML content on the page. If you want to allow them to do so, you can call `raw`, but do so with extreme care:

```heex
{raw("<b>Bold?</b>")}
```

Another super power of HEEx templates is validation of HTML and interpolation syntax of attributes. You can write:

```heex
<div title="My div" class={@class}>
  <p>Hello {@username}</p>
</div>
```

Notice how you could simply use `key={value}`. HEEx will automatically handle special values such as `false` to remove the attribute or a list of classes.

To interpolate a dynamic number of attributes in a keyword list or map, do:

```heex
<div title="My div" {@many_attributes}>
  <p>Hello {@username}</p>
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
  <li :for={item <- @items}>{item.name}</li>
</ul>
```

## CoreComponents

In a new Phoenix application, you will also find a `core_components.ex` module inside the `components` folder. This module is a great example of defining function components to be reused throughout our application. This guarantees that, as our application evolves, our components will look consistent.

If you look inside `def html` in `HelloWeb` placed at `lib/hello_web.ex`, you will see that `CoreComponents` are automatically imported into all HTML views via `use HelloWeb, :html`. This is also the reason why `CoreComponents` itself performs `use Phoenix.Component` instead of `use HelloWeb, :html` at the top: doing the latter would cause a deadlock as we would try to import `CoreComponents` into itself.

CoreComponents also play an important role in Phoenix code generators, as the code generators assume those components are available in order to quickly scaffold your application. In case you want to learn more about all of these pieces, you may:

  * Explore the generated `CoreComponents` module to learn more from practical examples

  * Read the official documentation for [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)

  * Read the official documentation for [HEEx and the ~H sigils](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2)

  * If you are looking for higher level components beyond the minimal ones included by Phoenix, [the LiveView project keeps a list of component systems](https://github.com/phoenixframework/phoenix_live_view#component-systems)

## Layouts

When talking about components and rendering in Phoenix, it is important to understand the concept of layouts.

All Phoenix applications have one component called the "root layout". This page is where you will find the `<head>` and `<body>` tags of your HTML page. The root layout is configured in your `lib/hello_web/router.ex` file:

```elixir
  plug :put_root_layout, html: {HelloWeb.Layouts, :root}
```

In a newly generated app, the template itself can be found at `lib/hello_web/components/layouts/root.html.heex`. Open it up and, just about at the end of the `<body>`, you will see this:

```heex
{@inner_content}
```

That's where our templates are injected once they are rendered. The root layout is reused by controllers and live views alike.

Any dynamic functionality of your application is then implemented as function components. For example, your application menu and sidebar is typically part of the `app` component in `lib/hello_web/components/layouts.ex`, which is invoked in every template:

```heex
<Layouts.app flash={@flash}>
  ...
</Layouts.app>
```

This mechanism is also very flexible. For example, if you want to create an admin layout, you can simply add a new function in the `Layouts` module, and then invoke `Layouts.admin` instead of `Layouts.app`:

```heex
<Layouts.admin flash={@flash}>
  ...
</Layouts.admin>
```

> Previous Phoenix versions used a nested layout mechanism, by passing the `:layouts` to `Phoenix.Controller` and `:layout` to `Phoenix.LiveView`, but this mechanism is discouraged in new Phoenix applications.
