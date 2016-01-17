Our task for this guide is to add two new pages to our Phoenix application. One will be a purely static page, and the other will take part of the path from the URL as input and pass it through to a template for display. Along the way, we will gain familiarity with the basic components of a Phoenix application: the router, controllers, views, and templates.

When Phoenix generates a new application for us, it builds a top-level directory structure like this:

```text
├── _build
├── config
├── deps
├── lib
├── priv
├── test
├── web
```

Most of our work in this guide will be in the `web` directory, which looks like this when expanded:

```text
├── channels
├── controllers
│   └── page_controller.ex
├── models
├── static
├── router.ex
├── templates
│   ├── layout
│   │   └── app.html.eex
│   └── page
│       └── index.html.eex
└── views
|   ├── error_view.ex
|   ├── layout_view.ex
|   └── page_view.ex
└── web.ex
```

All of the files which are currently in the `controllers`, `templates`, and `views` directories are there to create the "Welcome to Phoenix!" page we saw in the last guide. We will see how we can re-use some of that code shortly. By convention, in the development environment, anything in the `web` directory will be automatically recompiled when there is a new web request.

All of our application's static assets live in `priv/static` in the directory appropriate for each type of file - css, images or js. We place assets that require a build phase into `web/static`, and the source files are built into their respective `app.js` / `app.css` bundles within `priv/static`. We won't be making any changes here for now, but it is good to know where to look for future reference.

```text
priv
└── static
    └── images
        └── phoenix.png
```

```text
web
└── static
    ├── css
    |   └── app.css
    ├── js
    │   └── app.js
    └── vendor
        └── phoenix.js
```

The `lib` directory also contains files we should know about. Our application's endpoint is at `lib/hello_phoenix/endpoint.ex`, and our application file (which starts our application and its supervision tree) is at `lib/hello_phoenix.ex`.

```text
lib
├── hello_phoenix
|   ├── endpoint.ex
│   └── repo.ex
└── hello_phoenix.ex
```

Unlike the `web` directory, Phoenix won't recompile files inside of `lib` when there is a new web request. This is intentional! The distinction between `web` and `lib` provides a convention for the different ways that we handle state inside of our application. The 'web' directory contains anything whose state lasts for the duration of a web request. The `lib` directory contains both shared modules and anything that needs to manage state outside of the duration of a web request.

Enough prep, let's get on with our first new Phoenix page!

### A New Route

Routes map unique HTTP verb/path pairs to controller/action pairs which will handle them. Phoenix generates a router file for us in new applications at `web/router.ex`. This is where we will be working for this section.

The route for our "Welcome to Phoenix!" page from the previous Up And Running Guide looks like this.
```elixir
get "/", PageController, :index
```
Let's digest what this route is telling us. Visiting [http://localhost:4000/](http://localhost:4000/) issues an HTTP `GET` request to the root path. All requests like this will be handled by the `index` function in the `HelloPhoenix.PageController` module defined in `web/controllers/page_controller.ex`.

The page we are going to build will simply say "Hello World, from Phoenix!" when we point our browser to [http://localhost:4000/hello](http://localhost:4000/hello).

The first thing we need to do to create that page is define a route for it. Let's open up `web/router.ex` in a text editor. It should currently look like this:

```elixir
defmodule HelloPhoenix.Router do
  use HelloPhoenix.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HelloPhoenix do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloPhoenix do
  #   pipe_through :api
  # end
end

```
For now, we'll ignore the pipelines and the use of `scope` here and just focus on adding a route. (We cover these topics in the [Routing Guide](http://www.phoenixframework.org/docs/routing), if you're curious.)

Let's add a new route to the router that maps a `GET` request for `/hello` to the `index` action of a soon-to-be-created `HelloPhoenix.HelloController`:

```elixir
get "/hello", HelloController, :index
```

The `scope "/"` block of our `router.ex` file should now look like this:

```elixir
scope "/", HelloPhoenix do
  pipe_through :browser # Use the default browser stack

  get "/", PageController, :index
  get "/hello", HelloController, :index
end
```

### A New Controller

Controllers are Elixir modules, and actions are Elixir functions defined in them. The purpose of actions is to gather any data and perform any tasks needed for rendering. Our route specifies that we need a `HelloPhoenix.HelloController` module with an `index/2` action.

To make that happen, let's create a new `web/controllers/hello_controller.ex` file, and make it look like the following:

```elixir
defmodule HelloPhoenix.HelloController do
  use HelloPhoenix.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
```
We'll save a discussion of `use HelloPhoenix.Web, :controller` for the [Controllers Guide](http://www.phoenixframework.org/docs/controllers). For now, let's focus on the `index/2` action.

All controller actions take two arguments. The first is `conn`, a struct which holds a ton of data about the request. The second is `params`, which are the request parameters. Here, we are not using `params`, and we avoid compiler warnings by adding the leading `_`.

The core of this action is `render conn, "index.html"`. This tells Phoenix to find a template called `index.html.eex` and render it. Phoenix will look for the template in a directory named after our controller, so `web/templates/hello`.

> Note: Using an atom as the template name will also work here, `render conn, :index`, but the template will be chosen based off the Accept headers, e.g. `"index.html"` or `"index.json"`.

The modules responsible for rendering are views, and we'll make a new one of those next.

### A New View

Phoenix views have several important jobs. They render templates. They also act as a presentation layer for raw data from the controller, preparing it for use in a template. Functions which perform this transformation should go in a view.

As an example, say we have a data structure which represents a user with a `first_name` field and a `last_name` field, and in a template, we want to show the user's full name. We could write code in the template to merge those fields into a full name, but the better approach is to write a function in the view to do it for us, then call that function in the template. The result is a cleaner and more legible template.

In order to render any templates for our `HelloController`, we need a `HelloView`. The names are significant here - the first part of the names of the view and controller must match. Let's create an empty one for now, and leave a more detailed description of views for later. Create `web/views/hello_view.ex` and make it look like this:

```elixir
defmodule HelloPhoenix.HelloView do
  use HelloPhoenix.Web, :view
end
```

### A New Template

Phoenix templates are just that, templates into which data can be rendered. The standard templating engine Phoenix uses is EEx, which stands for [Embedded Elixir](http://elixir-lang.org/docs/stable/eex/). All of our template files will have the `.eex` file extension.

Templates are scoped to a view, which are scoped to controller. In practice, this simply means that we create a directory named after the controller in the `web/templates` directory. For our hello page, that means we need to create a `hello` directory under `web/templates` and then create an `index.html.eex` file within it.

Let's do that now. Create `web/templates/hello/index.html.eex` and make it look like this:

```html
<div class="jumbotron">
  <h2>Hello World, from Phoenix!</h2>
</div>
```

Now that we've got the route, controller, view, and template, we should be able to point our browsers at [http://localhost:4000/hello](http://localhost:4000/hello) and see our greeting from Phoenix! (In case you stopped the server along the way, the task to restart it is `mix phoenix.server`.)

![Phoenix Greets Us](/images/hello-from-phoenix.png)

There are a couple of interesting things to notice about what we just did. We didn't need to stop and re-start the server while we made these changes. Yes, Phoenix has hot code reloading! Also, even though our `index.html.eex` file consisted of only a single `div` tag, the page we get is a full HTML document. Our index template is rendered into the application layout - `web/templates/layout/app.html.eex`. If you open it, you'll see a line that looks like this:

    <%= render @view_module, @view_template, assigns %>

which is what renders our template into the layout before the HTML is sent off to the browser.

## Another New Page

Let's add just a little complexity to our application. We're going to add a new page that will recognize a piece of the URL, label it as a "messenger" and pass it through the controller into the template so our messenger can say hello.

As we did last time, the first thing we'll do is create a new route.

### A New Route

For this exercise, we're going to re-use the `HelloController` we just created and just add a new `show` action. We'll add a line just below our last route, like this:

```elixir
scope "/", HelloPhoenix do
  pipe_through :browser # Use the default browser stack.

  get "/", PageController, :index
  get "/hello", HelloController, :index
  get "/hello/:messenger", HelloController, :show
end
```
Notice that we put the atom `:messenger` in the path. Phoenix will take whatever value that appears in that position in the URL and pass a [Map](http://elixir-lang.org/docs/stable/elixir/Map.html) with the key `messenger` pointing to that value to the controller.

For example, if we point the browser at: [http://localhost:4000/hello/Frank](http://localhost:4000/hello/Frank), the value of ":messenger" will be "Frank".

### A New Action

Requests to our new route will be handled by the `HelloPhoenix.HelloController` `show` action. We already have the controller at `web/controllers/hello_controller.ex`, so all we need to do is edit that file and add a `show` action to it. This time, we'll need to keep one of the items in the map of params that gets passed into the action, so that we can pass it (the messenger) to the template. To do that, we add this show function to the controller:

```elixir
def show(conn, %{"messenger" => messenger}) do
  render conn, "show.html", messenger: messenger
end
```
There are a couple of things to notice here. We pattern match against the params passed into the show function so that the `messenger` variable will be bound to the value we put in the `:messenger` position in the URL. For example, if our URL is [http://localhost:4000/hello/Frank](http://localhost:4000/hello/Frank), the messenger variable would be bound to `Frank`.

Within the body of the `show` action, we also pass a third argument into the render function, a key/value pair where `:messenger` is the key, and the `messenger` variable is passed as the value.

> Note: If the body of the action needs access to the full map of parameters bound to the params variable in addition to the bound messenger variable, we could define `show/2` like this:

```elixir
def show(conn, %{"messenger" => messenger} = params) do
  ...
end
```

It's good to remember that the keys to the `params` map will always be strings, and that the equals sign does not represent assignment, but is instead a [pattern match](http://elixir-lang.org/getting-started/pattern-matching.html) assertion.

### A New Template

For the last piece of this puzzle, we'll need a new template. Since it is for the `show` action of the `HelloController`, it will go into the `web/templates/hello` directory and be called `show.html.eex`. It will look surprisingly like our `index.html.eex` template, except that we will need to display the name of our messenger.

To do that, we'll use the special EEx tags for executing Elixir expressions - `<%=  %>`. Notice that the initial tag has an equals sign like this: `<%=` . That means that any Elixir code that goes between those tags will be executed, and the resulting value will replace the tag. If the equals sign were missing, the code would still be executed, but the value would not appear on the page.

And this is what the template should look like:

```html
<div class="jumbotron">
  <h2>Hello World, from <%= @messenger %>!</h2>
</div>
```

Our messenger appears as `@messenger`. In this case, this is not a module attribute. It is special bit of metaprogrammed syntax which stands in for `Dict.get(assigns, :messenger)`. The result is much nicer on the eyes and much easier to work with in a template.

We're done. If you point your browser here: [http://localhost:4000/hello/Frank](http://localhost:4000/hello/Frank), you should see a page that looks like this:

![Frank Greets Us from Phoenix](/images/hello-world-from-frank.png)

Play around a bit. Whatever you put after `/hello/` will appear on the page as your messenger.
