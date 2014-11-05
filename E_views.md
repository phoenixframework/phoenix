##Views

Phoenix views have two main jobs. First and foremost, they render templates (this includes layouts). The core function involved in rendering, `render/3`, is defined in `Phoenix.View`. Views also provide functions which take raw data and make it easier for templates to consume. If you are familiar with decorators or the facade pattern, this is similar.

Phoenix defines view behavior in layers. The deepest level is `Phoenix.View`, from Phoenix itself, which doesn't appear in our generated application code. Since Phoenix is a dependency of our application, we have access to `Phoenix.View` even though we don't see it directly.

The next layer is the main application view, which will be `web/view.ex` in a newly generated app. The main view brings in all the behavior from `Phoenix.View` via `use Phoenix.View`. In the main view we can also import functions, use modules, and alias modules which need to be available to other views.

Individual views are the final layer. These will all gain access to the behavior collected in the main application view by using it. In our case, that is `use HelloPhoenix.View`. A newly generated app will have two of these, `web/views/layout_view.ex` and `web/views/page_view.ex`.

Looking back up the chain, individual views use the main view which uses the Phoenix view.

It's important to note that the scope of the main view is global to all views and templates in the application, and individual views are scoped to a single directory of templates.

### Main Application View

Let's take a look at the main view.  Please note, this is from the current master branch. If you are using 0.5.0, please see the
[Phoenix Views documentation](http://hexdocs.pm/phoenix/0.5.0/Phoenix.View.html) on Hexdocs. There are some differences, but by looking at both examples, the relationship between the two should become clear.

```elixir
defmodule HelloPhoenix.View do
  use Phoenix.View, root: "web/templates"

  # Everything that is imported, aliased, or used in this block is available
  # in the rest of this module and in any other view module that uses it.
  using do
    # Import common functionality
    import HelloPhoenix.I18n
    import HelloPhoenix.Router.Helpers

    # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
    use Phoenix.HTML

    # Common aliases
    alias Phoenix.Controller.Flash
  end

  # Functions defined here are available to all other views/templates
end
```

Besides bringing in all the functions and aliases available to `Phoenix.Veiw`, the first line allows us to set the root directory within which Phoenix will look for templates. By default, that is `web/templates`. If we need to change that, this is the place to do so.

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

The `<%=` and `%>` are from the Elixir Eex project. They enclose executable Elixir code within a template. The '=' tells Eex to print the result. If the '=' is not there, Eex wills still execute the code, but there will be no output. In our example, we are calling the `title` function from `HelloPhoenix.View` and printing the output into the title tag.

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
  <p><a href="<%= page_path :index %>">Link back to ourselves</a></p>
</div>
```

Let's reload the page and view source to see what we have.

```html
<a href="/">Link back to ourselves</a>
```

Great, `page_path/1` evaluated to "/" as we would expect, and we didn't need to qualify it with `HelloPhoenix.View`.


###Individual Views

Individual views have a much narrower scope. Their job is to render, and provide decorating functions for, a single directory of templates. Phoenix assumes a strong naming convention from controllers to views to the templates they render. The `PageController` requires a `PageView` to render templates in the `web/templates/page` directory. If we change the `:root` declaration in the main view, of course, Phoenix would look for a `page` directory within the directory we set there.

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

This doesn't correspond to any action in our controller, but we'll exercise it in a mix console. At the root of our project, we can run `iex -S mix`, and then explicitly render our template.

```console
iex(1)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", %{})
{:safe, "This is the message: Hello from the view!\n"}
```
As we can see, we're calling `render/3` with the individual view responsible for our test template, the name of our test template, and an empty map representing any data we might have wanted to pass in.

The return value is a tuple beginning with the atom `:safe` and the resultant string of the interpolated template.

"Safe" here means that Phoenix has escaped the contents of our rendered template. Phoenix defines it's own `Phoenix.HTML.Safe` protocol with implementations for atoms, bitstrings, lists, integers, floats, and tuples to handle this escaping for us as our templates are rendered into strings.

What happens if we assign some key value pairs to the third argument of `render/3`? In order to find out, we need to change the template just a bit.

```html
I came from assigns: <%= @message %>
This is the message: <%= message %>
```

Note the "@" in the top line. Now if we change our function call, we see a different rendering.

```console
iex(2)> Phoenix.View.render(HelloPhoenix.PageView, "test.html", message: "Assigns has an @.")
{:safe,
 "I came from assigns: Assigns has an @.\nThis is the message: Hello from the view!\n"}
 ```

TODO
- render layouts => @inner
- render_to_iodata
