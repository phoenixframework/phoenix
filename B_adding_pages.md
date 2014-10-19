##New Pages

Our task for this guide is to add two new pages to our Phoenix application. One will be a purely static page, and the other will take part of the path from the url as input and pass it through to a template for display. Along the way, we will gain familiarity with the basic components of a Phoenix application: the router, controllers, views and templates.


When Phoenix generates a new application for us, it builds a top level directory structure like this.

```text
├── _build
├── config
├── deps
├── lib
├── priv
├── test
├── web
```


Most of our work in this tutorial will be in the web directory, which looks like this when expanded.

```text
├── channels
├── controllers
│   └── page_controller.ex
├── i18n.ex
├── models
├── router.ex
├── templates
│   ├── layout
│   │   └── application.html.eex
│   └── page
│       └── index.html.eex
├── views
│   ├── layout_view.ex
│   └── page_view.ex
└── views.ex
```

All of the files which are currently in the controllers, templates and views directories are there to create the "Welcome to Phoenix!" page we saw in the last guide. We will see how we can re-use some of that code shortly.

All of our application's static assets live in priv/static in the directory appropriate for each type of file - css, images or js. We won't be making any changes here for now, but it's good to know where to look for future reference.

```text
priv
└── static
    ├── css
    │   └── app.css
    ├── images
    └── js
        └── phoenix.js
```

Enough prep, let's get on with our first new Phoenix page!


###A New Route

Routes map unique http verb/path pairs to controller/action pairs which will handle them. The route for our "Welcome to Phoenix!" page from the previous guide looks like this.

```elixir
get "/", HelloPhoenix.PageController, :index
```
If you are working with the 0.5.0 Phoenix release or earlier, there will be an extra `as: :pages` option added to your route. This is no longer necessary on the master branch or later releases.

```elixir
get "/", HelloPhoenix.PageController, :index, as: :pages
```

Let's digest what this route is telling us. Visiting http://localhost:4000 issues an http GET request to the root path. All requests like this will be handled by the "index" function in the "HelloPhoenix.PageController" module defined in web/controllers/page_controller.ex.

The page we are going to build will simply say "Hello from Phoenix!" when we point our browser to http://localhost:4000/hello.

The first thing we need to do to create that page is define a route for it. Open up `web/router.ex` in your favorite text editor. It should currently look like this.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  scope "/" do
    # Use the default browser stack.
    pipe_through :browser

    get "/", HelloPhoenix.PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api" do
  #   pipe_through :api
  # end
end
```

For now, we'll ignore the use of `scope` here and focus on adding a route.

Let's add a new route to the router that maps the GET for "/hello" to the index action of a soon-to-be created HelloPhoenix.HelloController. Like so:

```elixir
get "/hello", HelloPhoenix.HelloController, :index
```

Your router.ex file should now look like this.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  scope "/" do
    # Use the default browser stack.
    pipe_through :browser

    get "/", HelloPhoenix.PageController, :index
    get "/hello", HelloPhoenix.HelloController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api" do
  #   pipe_through :api
  # end
end
```

###A New Controller

Controllers are Elixir modules, and actions are Elixir functions defined on them. The purpose of actions is to gather any data and perform any tasks needed for rendering. Our route specifies that we need a HelloPhoenix.HelloController module with an index function. Let's do that now.

Create a new web/controllers/hello_controller.ex file, and make it look like the following.

```elixir
defmodule HelloPhoenix.HelloController do
  use Phoenix.Controller

  plug :action

  def index(conn, _params) do
    render conn, "index"
  end
end
```

We will save a more complete discussion of controllers for the controller specific guide, but for now, the interesting part is this line.

```elixir
render conn, "index"
```

This simply says that we want to render the index.html.eex template for our hello_controller.ex. Notice that we are ignoring the params argument to the index function. We aren't taking input from the request at all to render this page.

On to rendering!

###A New View

Phoenix views have several important jobs. They actually render templates. They also act as a presentation layer for raw data from the controller, preparing it for use in a template. Functions which perform this transformation should go in a view.

As an example, say we have a data structure which represents a user with a first_name field and a last_name field, and in a template, we want to show the user's full name. We could write code in the template to merge those fields into a full name, but the better approach is to write a function in the view to do it for us, then call that function in the template. The result is a cleaner and more legible template.

It's also important to note that each Phoenix application has a base view located at web/views.ex. Functions defined there will be available to all the views we define in the web/views directory.

In order to render any templates for our HelloController, we need a HelloView. The names are significant here - the first part of the names of the view and controller must match. Let's create an empty one for now, and leave a more detailed description of views for later. Create web/views/hello_view.ex and make it look like this.

```elixir
defmodule HelloPhoenix.HelloView do
  use HelloPhoenix.Views
end
```

###A New Template

Phoenix templates are just that, templates into which data can be rendered. The standard templating engine Phoenix uses is eex, which stands for Embedded Elixir. http://elixir-lang.org/docs/stable/eex/ All our template files will have the .eex file extension.

Templates are scoped to a controller. In practice, this simply means that we create a directory named after the controller in the web/templates directory. For our hello page, that means we need to create a "hello" directory under web/templates and then create an index.html.eex file within it.

Let's do that now. Create web/templates/hello/index.html.eex and make it look like this.

```html
<div class="jumbotron">
  <h2>Hello from Phoenix!</h2>
</div>
```

Now that we've got the route, controller, view and template, we should be able to point our browsers at http://localhost:4000/hello and see our greeting from Phoenix!

![Phoenix Greets Us](/images/hello-from-phoenix.png)

There are a couple of interesting things to notice about what we just did. We didn't need to stop and re-start the server while we made these changes. Yes, Phoenix has hot code re-loading! Also, even though our index.html.eex file consisted of only a single div tag, The page we get is a full html document. Our index template is rendered into the application layout - web/templates/layout/application.html.eex. If you open it, you'll see a tag that looks like this: <%= @inner %>, which is what injects our rendered template into the layout before the html is sent off to the browser.

##Another New Page

Let's add just a little complexity to our application. We're going to add a new page that will recognize a piece of the url, label it as a "messenger" and pass it through the controller into the template so our messenger can say hello.

As we did last time, the first thing we'll do is create a new route.

###A New Route

For this page, we're going to re-use our HelloController we just created and just add a new "show" action. We'll add a line just below our last route, like this.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  scope "/" do
    # Use the default browser stack.
    pipe_through :browser

    get "/", HelloPhoenix.PageController, :index
    get "/hello", HelloPhoenix.HelloController, :index
    get "/hello/:messenger", HelloPhoenix.HelloController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api" do
  #   pipe_through :api
  # end
end
```
Notice that we put the atom ":messenger" in the path. Phoenix will take whatever value that appears in that position in the url and passes a Dict with the key "messanger" pointing to that value to the controller.

For example, if we point the browser at: http://localhost:4000/hello/Frank , the value of ":messenger" will be "Frank".

###A New Action

Requests to our new route will be handled by the HelloPhoenix.HelloController "show" action. We already have the controller, so all we need to do is add a "show" function to it. This time, we'll need to keep the params that get passed into the action so that we can pass the messenger to the template. To do that, we add this show function to the controller.

```elixir
def show(conn, %{"messenger" => messenger}) do
  render conn, "show", messenger: messenger
end
```

There are a couple of things to notice here. We pattern match against the params passed into the show function so that the messenger variable will be bound to the value we put in the :messenger position in the url. For example, if our url is http://localhost:4000/hello/Frank, the messenger variable would be bound to "Frank".

We also pass a third argument into the render function, a key value pair where ":messenger" is the key, and the messenger variable is passed as the value.

It's good to remember that the keys to the params Dict will always be strings.

###A New Template

For the last piece of this puzzle, we'll need a new template. Since it is for the show action of the HelloController, it will go the web/templates/hello directory and be called show.html.eex. It will look surprisingly like our index.html.eex template, except that we will need to display the name of our messenger.

To do that, we'll use the special eex tags for executing Elixir expressions - <%=  %>. Notice that the initial tag has an equals sign like this: <%= . That means that any Elixir code that goes between those tags will be executed, and the resulting value will replace the tag. If the equals sign were missing, the code would still be executed, but the value would not appear on the page.

And this is what the template should look like.

```html
<div class="jumbotron">
  <h2>Hello World, from <%= @messenger %>!</h2>
</div>
```

Our messenger appears as "@messenger". In this case, this is not a module attribute. It is special bit of metaprogrammed syntax which stands in for "Dict.get(assigns, :messenger)". The result is much nicer on the eyes and much easier to work with in a template.

We're done. If you point your browser here: http://localhost:4000/hello/Frank, you should see a page that looks like this:

![Frank Greets Us from Phoenix](/images/hello-world-from-frank.png)

Play around a bit. Whatever you put after /hello/ will appear on the page as your messenger.
