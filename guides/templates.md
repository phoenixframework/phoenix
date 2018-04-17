# Templates

Templates are what they sound like they should be: files into which we pass data to form complete HTTP responses. For a web application these responses would typically be full HTML documents. For an API, they would most often be JSON or possibly XML. The majority of the code in template files is often markup, but there will also be sections of Elixir code for Phoenix to compile and evaluate. The fact that Phoenix templates are pre-compiled makes them extremely fast.

EEx is the default template system in Phoenix, and it is quite similar to ERB in Ruby. It is actually part of Elixir itself, and Phoenix uses EEx templates to create files like the router and the main application view while generating a new application.

As we learned in the [View Guide](views.html), by default, templates live in the `lib/hello_web/templates` directory, organized into directories named after a view. Each directory has its own view module to render the templates in it.

### Examples

We've already seen several ways in which templates are used, notably in the [Adding Pages Guide](adding_pages.html) and the [Views Guide](views.html). We may cover some of the same territory here, but we will certainly add some new information.

##### hello_web.ex

Phoenix generates a `lib/hello_web.ex` file that serves as place to group common imports and aliases. All declarations here within the `view` block apply to all your templates.

Let's make some additions to our application so we can experiment a little.

First, let's define a new route in `lib/hello_web/router.ex`.

```elixir
defmodule HelloWeb.Router do
  ...

  scope "/", HelloWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/test", PageController, :test
  end

  # Other scopes may use custom stacks.
  # scope "/api", Hello do
  #   pipe_through :api
  # end
end
```

Now, let's define the controller action we specified in the route. We'll add a `test/2` action in the `lib/hello_web/controllers/page_controller.ex` file.

```elixir
defmodule HelloWeb.PageController do
  ...

  def test(conn, _params) do
    render conn, "test.html"
  end
end
```

We're going to create a function that tells us which controller and action are handling our request.

To do that, we need to import the `action_name/1` and `controller_module/1` functions from `Phoenix.Controller` in `lib/hello_web.ex`.

```elixir
  def view do
    quote do
      use Phoenix.View, root: "lib/hello_web/templates",
                        namespace: HelloWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1,
                                        action_name: 1, controller_module: 1]

      ...
    end
  end
```

Next, let's define a `handler_info/1` function at the bottom of the ` lib/hello_web/views/page_view.ex` which makes use of the `controller_module/1` and `action_name/1` functions we just imported. We'll also define a `connection_keys/1` function that we'll use in a moment.

```elixir
defmodule HelloWeb.PageView do
  use HelloWeb, :view

  def handler_info(conn) do
    "Request Handled By: #{controller_module conn}.#{action_name conn}"
  end

  def connection_keys(conn) do
    conn
    |> Map.from_struct()
    |> Map.keys()
  end
end
```

We have a route. We created a new controller action. We have made modifications to the main application view. Now all we need is a new template to display the string we get from `handler_info/1`. Let's create a new one at `lib/hello_web/templates/page/test.html.eex`.

```html
<div class="jumbotron">
  <p><%= handler_info @conn %></p>
</div>
```

Notice that `@conn` is available to us in the template for free via the `assigns` map.

If we visit [localhost:4000/test](http://localhost:4000/test), we will see that our page is brought to us by `Elixir.HelloWeb.PageController.test`.

We can define functions in any individual view in `lib/hello_web/views`. Functions defined in an individual view will only be available to templates which that view renders. For example, functions like our `handler_info` above, will only be available to templates in `lib/hello_web/templates/page`.

##### Displaying Lists

So far, we've only displayed singular values in our templates - strings here, and integers in other guides. How would we approach displaying all the elements of a list?

The answer is that we can use Elixir's list comprehensions.

Now that we have a function, visible to our template, that returns a list of keys in the `conn` struct, all we need to do is modify our `lib/hello_web/templates/page/test.html.eex` template a bit to display them.

We can add a header and a list comprehension like this.

```html
<div class="jumbotron">
  <p><%= handler_info @conn %></p>

  <h3>Keys for the conn Struct</h3>

  <%= for key <- connection_keys @conn do %>
    <p><%= key %></p>
  <% end %>
</div>
```

We use the list of keys returned by the `connection_keys` function as the source list to iterate over. Note that we need the `=` in both `<%=` - one for the top line of the list comprehension and the other to display the key. Without them, nothing would actually be displayed.

When we visit [localhost:4000/test](http://localhost:4000/test) again, we see all the keys displayed.

##### Render templates within templates

In our list comprehension example above, the part that actually displays the values is quite simple.

```html
<p><%= key %></p>
```
We are probably fine with leaving this in place. Quite often, however, this display code is somewhat more complex, and putting it in the middle of a list comprehension makes our templates harder to read.

The simple solution is to use another template! Templates are just function calls, so like regular code, composing your greater template by small, purpose-built functions can lead to clearer design. This is simply a continuation of the rendering chain we have already seen. Layouts are templates into which regular templates are rendered. Regular templates may have other templates rendered into them.

Let's turn this display snippet into its own template. Let's create a new template file at `lib/hello_web/templates/page/key.html.eex`, like this.

```html
<p><%= @key %></p>
```

We need to change `key` to `@key` here because this is a new template, not part of a list comprehension. The way we pass data into a template is by the `assigns` map, and the way we get the values out of the `assigns` map is by referencing the keys with a preceding `@`. `@` is actually a macro that translates `@key` to `Map.get(assigns, :key)`.

Now that we have a template, we simply render it within our list comprehension in the `test.html.eex` template.

```html
<div class="jumbotron">
  <p><%= handler_info @conn %></p>

  <h3>Keys for the conn Struct</h3>

  <%= for key <- connection_keys @conn do %>
    <%= render "key.html", key: key %>
  <% end %>
</div>
```

Let's take a look at [localhost:4000/test](http://localhost:4000/test) again. The page should look exactly as it did before.

##### Shared Templates Across Views

Often, we find that small pieces of data need to be rendered the same way in different parts of the application. It's a good practice to move these templates into their own shared directory to indicate that they ought to be available anywhere in the app.

Let's move our template into a shared view.

`key.html.eex` is currently rendered by the `HelloWeb.PageView` module, but we use a render call which assumes that the current schema is what we want to render with. We could make that explicit, and re-write it like this:

```html
<div class="jumbotron">
  ...

  <%= for key <- connection_keys @conn do %>
    <%= render HelloWeb.PageView, "key.html", key: key %>
  <% end %>
</div>
```

Since we want this to live in a new `lib/hello_web/templates/shared` directory, we need a new individual view to render templates in that directory, `lib/hello_web/views/shared_view.ex`.

```elixir
defmodule HelloWeb.SharedView do
  use HelloWeb, :view
end
```

Now we can move `key.html.eex` from the `lib/hello_web/templates/page` directory into the `lib/hello_web/templates/shared` directory. Once that happens, we can change the render call in `lib/hello_web/templates/page/test.html.eex` to use the new `HelloWeb.SharedView`.

```html
<%= for key <- connection_keys @conn do %>
  <%= render HelloWeb.SharedView, "key.html", key: key %>
<% end %>
```
Going back to [localhost:4000/test](http://localhost:4000/test) again. The page should look exactly as it did before.
