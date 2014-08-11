##New Pages

Our task for this guide is to add two new pages to our Phoenix application. One will be a purely static page, and the other will take part of the path from the url as input and pass it through to a template for display. Along the way, we will gain familiarity with the basic components of a Phoenix application: the router, controllers, views and templates.


When Phoenix generates a new application for us, it builds a top level directory structure like this.

```
├── _build
├── config
├── deps
├── lib
├── priv
├── test
├── web
```


Most of our work in this tutorial will be in the web directory, which looks like this when expanded.

```
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

```
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

```
get "/", HelloPhoenix.PageController, :index, as: :page
```

Let's digest what this route is telling us. Visiting http://localhost:4000 issues an http GET request to the root path. All requests like this will be handled by the "index" function in the "HelloPhoenix.PageController" module defined in web/controllers/page_controller.ex. (Let's ignore the "as: :page" part until we get to the routing guide.)

The page we are going to build will simply say "Hello from Phoenix!" when we point our browser to http://localhost:4000/hello.

The first thing we need to do to create that page is define a route for it. Open up web/router.ex in your favorite text editor. It should currently look like this.

``` elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :hello_phoenix
  get "/", HelloPhoenix.PageController, :index, as: :page
end
```

Let's add a new route to the router that maps the GET for "/hello" to the index action of a soon-to-be created HelloPhoenix.HelloController. Your router.ex file should now look like this.

```
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :hello_phoenix
  get "/", HelloPhoenix.PageController, :index, as: :page

  get "/hello", HelloPhoenix.HelloController, :index
end
```

###A New Controller

Controllers are Elixir modules, and actions are Elixir functions defined on them. Our route specifies that we need a HelloPhoenix.HelloController module with an index function. Let's do that now.

Create a new web/controllers/hello_controller.ex file, and make it look like the following.

``` elixir
defmodule HelloPhoenix.HelloController do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index"
  end
end
```

We will save a more complete discussion of controllers for the controller specific guide, but for now, the interesting part is this line.

```
render conn, "index"
```

This simply says that we want to render the index.html.eex template for our hello_controller.ex. Notice that we are ignorming the params arguement to the index function. We aren't taking input from the request at all to render this page.

On to rendering!

###A New View
[TODO figure out a good view definition for here]

In order to render any templates for our HelloController, we need a HelloView. Let's create an empty one for now, and leave a detailed description of views for later. Create web/views/hello_view.ex and make it look like this.

``` elixir
defmodule HelloPhoenix.HelloView do
  use HelloPhoenix.Views
end
```

###A New Template

Phoenix templates are just that, templates into which data can be rendered. The standard templating engine Phoenix uses is eex, which stands for Embedded Elixir. http://elixir-lang.org/docs/stable/eex/ All our template files will have the .eex file extension.

Templates are scoped to a controller. In practice, this simply means that we create a directory named after the controller in the web/templates directory. For our hello page, that means we need to create a "hello" directory under web/templates and then create an index.html.eex file within it.

Let's do that now. Create web/templates/hello/index.html.eex and make it look like this.

``` elixir
<div class="jumbotron">
  <h2>Hello from Phoenix!</h2>
</div>
```

Now that we've got the route, controller, view and template, we should be able to point our browsers at http://localhost:4000/hello and see our greeting from Phoenix!

- notice that the layout from the welcome page is re-used.

- notice that we are borrowing the "jumbotron" class from the existing css.

- notice that Phoenix does hot code reloading


##Another New Page

###A New Route

###A New Action

###A New Template
