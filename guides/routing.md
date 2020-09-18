# Routing

> **Requirement**: This guide expects that you have gone through the introductory guides and got a Phoenix application up and running.

> **Requirement**: This guide expects that you have gone through [the Request life-cycle guide](request_lifecycle.html).

Routers are the main hubs of Phoenix applications. They match HTTP requests to controller actions, wire up real-time channel handlers, and define a series of pipeline transformations scoped to a set of routes.

The router file that Phoenix generates, `lib/hello_web/router.ex`, will look something like this one:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

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

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloWeb do
  #   pipe_through :api
  # end
end
```

Both the router and controller module names will be prefixed with the name you gave your application instead of `HelloWeb`.

The first line of this module, `use HelloWeb, :router`, simply makes Phoenix router functions available in our particular router.

Scopes have their own section in this guide, so we won't spend time on the `scope "/", HelloWeb do` block here. The `pipe_through :browser` line will get a full treatment in the Pipeline section of this guide. For now, you only need to know that pipelines allow a set of plugs to be applied to different sets of routes.

Inside the scope block, however, we have our first actual route:

```elixir
get "/", PageController, :index
```

`get` is a Phoenix macro that corresponds to the HTTP verb GET. Similar macros exist for other HTTP verbs including POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE and HEAD.

## Examining Routes

Phoenix provides a great tool for investigating routes in an application: `mix phx.routes`.

Let's see how this works. Go to the root of a newly-generated Phoenix application and run `mix phx.routes`. You should see something like the following, generated with all routes you currently have:

```console
$ mix phx.routes
page_path  GET  /  HelloWeb.PageController :index
```

The route above tells us that any HTTP GET request for the root of the application will be handled by the `index` action of the `HelloWeb.PageController`.

`page_path` is an example of what Phoenix calls a path helper, and we'll talk about those very soon.

## Resources

The router supports other macros besides those for HTTP verbs like `get`, `post`, and `put`. The most important among them is `resources`. Let's add a resource to our `lib/hello_web/router.ex` file like this:

```elixir
scope "/", HelloWeb do
  pipe_through :browser

  get "/", PageController, :index
  resources "/users", UserController
end
```

For now it doesn't matter that we don't actually have a `HelloWeb.UserController`.

Run `mix phx.routes` once again at the root of your project. You should see something like the following:

```elixir
user_path  GET     /users           HelloWeb.UserController :index
user_path  GET     /users/:id/edit  HelloWeb.UserController :edit
user_path  GET     /users/new       HelloWeb.UserController :new
user_path  GET     /users/:id       HelloWeb.UserController :show
user_path  POST    /users           HelloWeb.UserController :create
user_path  PATCH   /users/:id       HelloWeb.UserController :update
           PUT     /users/:id       HelloWeb.UserController :update
user_path  DELETE  /users/:id       HelloWeb.UserController :delete
```

This is the standard matrix of HTTP verbs, paths, and controller actions. For a while, this was known as RESTful routes, but most consider this a misnomer nowadays. Let's look at them individually, in a slightly different order.

- A GET request to `/users` will invoke the `index` action to show all the users.
- A GET request to `/users/new` will invoke the `new` action to present a form for creating a new user.
- A GET request to `/users/:id` will invoke the `show` action with an id to show an individual user identified by that ID.
- A POST request to `/users` will invoke the `create` action to save a new user to the data store.
- A GET request to `/users/:id/edit` will invoke the `edit` action with an ID to retrieve an individual user from the data store and present the information in a form for editing.
- A PATCH request to `/users/:id` will invoke the `update` action with an ID to save the updated user to the data store.
- A PUT request to `/users/:id` will also invoke the `update` action with an ID to save the updated user to the data store.
- A DELETE request to `/users/:id` will invoke the `delete` action with an ID to remove the individual user from the data store.

If we don't feel that we need all of these routes, we can be selective using the `:only` and `:except` options to filter certain actions.

Let's say we have a read-only posts resource. We could define it like this:

```elixir
resources "/posts", PostController, only: [:index, :show]
```

Running `mix phx.routes` shows that we now only have the routes to the index and show actions defined.

```elixir
post_path  GET     /posts      HelloWeb.PostController :index
post_path  GET     /posts/:id  HelloWeb.PostController :show
```

Similarly, if we have a comments resource, and we don't want to provide a route to delete one, we could define a route like this.

```elixir
resources "/comments", CommentController, except: [:delete]
```

Running `mix phx.routes` now shows that we have all the routes except the DELETE request to the delete action.

```elixir
comment_path  GET    /comments           HelloWeb.CommentController :index
comment_path  GET    /comments/:id/edit  HelloWeb.CommentController :edit
comment_path  GET    /comments/new       HelloWeb.CommentController :new
comment_path  GET    /comments/:id       HelloWeb.CommentController :show
comment_path  POST   /comments           HelloWeb.CommentController :create
comment_path  PATCH  /comments/:id       HelloWeb.CommentController :update
              PUT    /comments/:id       HelloWeb.CommentController :update
```

The `Phoenix.Router.resources/4` macro describes additional options for customizing resource routes.

## Path Helpers

Path helpers are functions which are dynamically defined on the `Router.Helpers` module for an individual application. For us, that is `HelloWeb.Router.Helpers`. The name of each path helper is derived from the name of the controller used in the route definition. Our controller is `HelloWeb.PageController`, and `page_path` is the function which will return the path to the root of our application.

That's a mouthful. Let's see it in action. Run `iex -S mix` at the root of the project. When we call the `page_path` function on our router helpers with the `Endpoint` or connection and action as arguments, it returns the path to us.

```elixir
iex> HelloWeb.Router.Helpers.page_path(HelloWeb.Endpoint, :index)
"/"
```

This is significant because we can use the `page_path` function in a template to link to the root of our application. We can then use this helper in our templates:

```html
<%= link "Welcome Page!", to: Routes.page_path(@conn, :index) %>
```

The reason we can use `Routes.page_path` instead of the full `HelloWeb.Router.Helpers.page_path` name is because `HelloWeb.Router.Helpers` is aliased as `Routes` by default in the `view/0` block defined inside `lib/hello_web.ex`. This definition is made available to our templates through `use HelloWeb, :view`.

We can, of course, use `HelloWeb.Router.Helpers.page_path(@conn, :index)` instead, but the convention is to use the aliased version for conciseness. Note that the alias is only set automatically for use in views, controllers and templates - outside these you need either the full name, or to alias it yourself inside the module definition with `alias HelloWeb.Router.Helpers, as: Routes`.

Using path helpers makes it easy to ensure our controllers, views and templates are linking to pages our router can actually handle.

### More on Path Helpers

When we ran `mix phx.routes` for our user resource, it listed the `user_path` as the path helper function for each line of output. Here is what that translates to for each action:

```elixir
iex> alias HelloWeb.Router.Helpers, as: Routes
iex> alias HelloWeb.Endpoint
iex> Routes.user_path(Endpoint, :index)
"/users"

iex> Routes.user_path(Endpoint, :show, 17)
"/users/17"

iex> Routes.user_path(Endpoint, :new)
"/users/new"

iex> Routes.user_path(Endpoint, :create)
"/users"

iex> Routes.user_path(Endpoint, :edit, 37)
"/users/37/edit"

iex> Routes.user_path(Endpoint, :update, 37)
"/users/37"

iex> Routes.user_path(Endpoint, :delete, 17)
"/users/17"
```

What about paths with query strings? By adding an optional fourth argument of key value pairs, the path helpers will return those pairs in the query string.

```elixir
iex> Routes.user_path(Endpoint, :show, 17, admin: true, active: false)
"/users/17?admin=true&active=false"
```

What if we need a full url instead of a path? Just replace `_path` with `_url`:

```elixir
iex(3)> Routes.user_url(Endpoint, :index)
"http://localhost:4000/users"
```

The `_url` functions will get the host, port, proxy port, and SSL information needed to construct the full URL from the configuration parameters set for each environment. We'll talk about configuration in more detail in its own guide. For now, you can take a look at `config/dev.exs` file in your own project to see those values.

Whenever possible prefer to pass a `conn` (or `@conn` in your views) in place of an `Endpoint`.

## Nested Resources

It is also possible to nest resources in a Phoenix router. Let's say we also have a `posts` resource which has a many-to-one relationship with `users`. That is to say, a user can create many posts, and an individual post belongs to only one user. We can represent that by adding a nested route in `lib/hello_web/router.ex` like this:

```elixir
resources "/users", UserController do
  resources "/posts", PostController
end
```
When we run `mix phx.routes` now, in addition to the routes we saw for `users` above, we get the following set of routes:

```elixir
...
user_post_path  GET     /users/:user_id/posts           HelloWeb.PostController :index
user_post_path  GET     /users/:user_id/posts/:id/edit  HelloWeb.PostController :edit
user_post_path  GET     /users/:user_id/posts/new       HelloWeb.PostController :new
user_post_path  GET     /users/:user_id/posts/:id       HelloWeb.PostController :show
user_post_path  POST    /users/:user_id/posts           HelloWeb.PostController :create
user_post_path  PATCH   /users/:user_id/posts/:id       HelloWeb.PostController :update
                PUT     /users/:user_id/posts/:id       HelloWeb.PostController :update
user_post_path  DELETE  /users/:user_id/posts/:id       HelloWeb.PostController :delete
```

We see that each of these routes scopes the posts to a user ID. For the first one, we will invoke the `PostController` `index` action, but we will pass in a `user_id`. This implies that we would display all the posts for that individual user only. The same scoping applies for all these routes.

When calling path helper functions for nested routes, we will need to pass the IDs in the order they came in the route definition. For the following `show` route, `42` is the `user_id`, and `17` is the `post_id`. Let's remember to alias our `HelloWeb.Endpoint` before we begin.

```elixir
iex> alias HelloWeb.Endpoint
iex> HelloWeb.Router.Helpers.user_post_path(Endpoint, :show, 42, 17)
"/users/42/posts/17"
```

Again, if we add a key/value pair to the end of the function call, it is added to the query string.

```elixir
iex> HelloWeb.Router.Helpers.user_post_path(Endpoint, :index, 42, active: true)
"/users/42/posts?active=true"
```

If we had aliased the `Helpers` module as before (it is only automatically aliased for views, templates and controllers, in this case, since we're inside `iex` we need to do it ourselves), we could instead do:

```elixir
iex> alias HelloWeb.Router.Helpers, as: Routes
iex> alias HelloWeb.Endpoint
iex> Routes.user_post_path(Endpoint, :index, 42, active: true)
"/users/42/posts?active=true"
```

## Scoped Routes

Scopes are a way to group routes under a common path prefix and scoped set of plugs. We might want to do this for admin functionality, APIs, and especially for versioned APIs. Let's say we have user generated reviews on a site, and that those reviews first need to be approved by an admin. The semantics of these resources are quite different, and they might not share the same controller. Scopes enable us to segregate these routes.

The paths to the user facing reviews would look like a standard resource.

```console
/reviews
/reviews/1234
/reviews/1234/edit
...
```

The admin review paths could be prefixed with `/admin`.

```console
/admin/reviews
/admin/reviews/1234
/admin/reviews/1234/edit
...
```

We accomplish this with a scoped route that sets a path option to `/admin` like this one. We could nest this scope inside another scope, but instead let's set it by itself at the root:

```elixir
scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

We define a new scope where all routes are prefixed with "/admin" and all controllers are under the `HelloWeb.Admin` namespace.

Running `mix phx.routes` again, in addition to the previous set of routes we get the following:

```elixir
...
review_path  GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
review_path  GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
review_path  GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
review_path  GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
review_path  POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
review_path  PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
             PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
review_path  DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
```

This looks good, but there is a problem here. Remember that we wanted both user facing reviews routes `/reviews` as well as the admin ones `/admin/reviews`. If we now include the user facing reviews in our router under the root scope like this:

```elixir
scope "/", HelloWeb do
  pipe_through :browser

  ...
  resources "/reviews", ReviewController
end

scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

and we run `mix phx.routes`, we get this output:

```elixir
...
review_path  GET     /reviews                 HelloWeb.ReviewController :index
review_path  GET     /reviews/:id/edit        HelloWeb.ReviewController :edit
review_path  GET     /reviews/new             HelloWeb.ReviewController :new
review_path  GET     /reviews/:id             HelloWeb.ReviewController :show
review_path  POST    /reviews                 HelloWeb.ReviewController :create
review_path  PATCH   /reviews/:id             HelloWeb.ReviewController :update
             PUT     /reviews/:id             HelloWeb.ReviewController :update
review_path  DELETE  /reviews/:id             HelloWeb.ReviewController :delete
...
review_path  GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
review_path  GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
review_path  GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
review_path  GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
review_path  POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
review_path  PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
             PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
review_path  DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
```

The actual routes we get all look right, except for the path helper `review_path` at the beginning of each line. We are getting the same helper for both the user facing review routes and the admin ones, which is not correct.

We can fix this problem by adding an `as: :admin` option to our admin scope:

```elixir

scope "/admin", HelloWeb.Admin, as: :admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

`mix phx.routes` now shows us we have what we are looking for.

```elixir
...
      review_path  GET     /reviews                        HelloWeb.ReviewController :index
      review_path  GET     /reviews/:id/edit               HelloWeb.ReviewController :edit
      review_path  GET     /reviews/new                    HelloWeb.ReviewController :new
      review_path  GET     /reviews/:id                    HelloWeb.ReviewController :show
      review_path  POST    /reviews                        HelloWeb.ReviewController :create
      review_path  PATCH   /reviews/:id                    HelloWeb.ReviewController :update
                   PUT     /reviews/:id                    HelloWeb.ReviewController :update
      review_path  DELETE  /reviews/:id                    HelloWeb.ReviewController :delete
...
admin_review_path  GET     /admin/reviews                  HelloWeb.Admin.ReviewController :index
admin_review_path  GET     /admin/reviews/:id/edit         HelloWeb.Admin.ReviewController :edit
admin_review_path  GET     /admin/reviews/new              HelloWeb.Admin.ReviewController :new
admin_review_path  GET     /admin/reviews/:id              HelloWeb.Admin.ReviewController :show
admin_review_path  POST    /admin/reviews                  HelloWeb.Admin.ReviewController :create
admin_review_path  PATCH   /admin/reviews/:id              HelloWeb.Admin.ReviewController :update
                   PUT     /admin/reviews/:id              HelloWeb.Admin.ReviewController :update
admin_review_path  DELETE  /admin/reviews/:id              HelloWeb.Admin.ReviewController :delete
```

The path helpers now return what we want them to as well. Run `iex -S mix` and give it a try yourself.

```elixir
iex(1)> HelloWeb.Router.Helpers.review_path(HelloWeb.Endpoint, :index)
"/reviews"

iex(2)> HelloWeb.Router.Helpers.admin_review_path(HelloWeb.Endpoint, :show, 1234)
"/admin/reviews/1234"
```

What if we had a number of resources that were all handled by admins? We could put all of them inside the same scope like this:

```elixir
scope "/admin", HelloWeb.Admin, as: :admin do
  pipe_through :browser

  resources "/images",  ImageController
  resources "/reviews", ReviewController
  resources "/users",   UserController
end
```

Here's what `mix phx.routes` tells us:

```elixir
...
 admin_image_path  GET     /admin/images            HelloWeb.Admin.ImageController :index
 admin_image_path  GET     /admin/images/:id/edit   HelloWeb.Admin.ImageController :edit
 admin_image_path  GET     /admin/images/new        HelloWeb.Admin.ImageController :new
 admin_image_path  GET     /admin/images/:id        HelloWeb.Admin.ImageController :show
 admin_image_path  POST    /admin/images            HelloWeb.Admin.ImageController :create
 admin_image_path  PATCH   /admin/images/:id        HelloWeb.Admin.ImageController :update
                   PUT     /admin/images/:id        HelloWeb.Admin.ImageController :update
 admin_image_path  DELETE  /admin/images/:id        HelloWeb.Admin.ImageController :delete
admin_review_path  GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
admin_review_path  GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
admin_review_path  GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
admin_review_path  GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
admin_review_path  POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
admin_review_path  PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
                   PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
admin_review_path  DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
  admin_user_path  GET     /admin/users             HelloWeb.Admin.UserController :index
  admin_user_path  GET     /admin/users/:id/edit    HelloWeb.Admin.UserController :edit
  admin_user_path  GET     /admin/users/new         HelloWeb.Admin.UserController :new
  admin_user_path  GET     /admin/users/:id         HelloWeb.Admin.UserController :show
  admin_user_path  POST    /admin/users             HelloWeb.Admin.UserController :create
  admin_user_path  PATCH   /admin/users/:id         HelloWeb.Admin.UserController :update
                   PUT     /admin/users/:id         HelloWeb.Admin.UserController :update
  admin_user_path  DELETE  /admin/users/:id         HelloWeb.Admin.UserController :delete
```

This is great, exactly what we want. Note how every route, path helper and controller is properly namespaced.

Scopes can also be arbitrarily nested, but you should do it carefully as nesting can sometimes make our code confusing and less clear. With that said, suppose that we had a versioned API with resources defined for images, reviews and users. Then technically we could setup routes for the versioned API like this:

```elixir
scope "/api", HelloWeb.Api, as: :api do
  pipe_through :api

  scope "/v1", V1, as: :v1 do
    resources "/images",  ImageController
    resources "/reviews", ReviewController
    resources "/users",   UserController
  end
end
```

You can run `mix phx.routes` to see how these definitions will look like.

Interestingly, we can use multiple scopes with the same path as long as we are careful not to duplicate routes. This router is perfectly fine with two scopes defined for the same path.

```elixir
defmodule HelloWeb.Router do
  use Phoenix.Router
  ...
  scope "/", HelloWeb do
    pipe_through :browser

    resources "/users", UserController
  end

  scope "/", AnotherAppWeb do
    pipe_through :browser

    resources "/posts", PostController
  end
  ...
end
```

If we do duplicate a route, we'll get this familiar warning.

```console
warning: this clause cannot match because a previous clause at line 16 always matches
```

## Pipelines

We have come quite a long way in this guide without talking about one of the first lines we saw in the router - `pipe_through :browser`. It's time to fix that.

Pipelines are a series of plugs that can be attached to specific scopes. If you are not familiar with plugs, we have an [in-depth guide about them](plug.html).

Routes are defined inside scopes and scopes may pipe through multiple pipelines. Once a route matches, Phoenix invokes all plugs defined in all pipelines associated to that route. For example, accessing "/" will pipe through the `:browser` pipeline, consequently invoking all of its plugs.

Phoenix defines two pipelines by default, `:browser` and `:api`, which can be used for a number of common tasks. In turn we can customize them as well as create new pipelines to meet our needs.

### The `:browser` and `:api` Pipelines

As their names suggest, the `:browser` pipeline prepares for routes which render requests for a browser. The `:api` pipeline prepares for routes which produce data for an api.

The `:browser` pipeline has five plugs: `plug :accepts, ["html"]` which defines the request format or formats which will be accepted, `:fetch_session`, which, naturally, fetches the session data and makes it available in the connection, `:fetch_flash` which retrieves any flash messages which may have been set, as well as `:protect_from_forgery` and `:put_secure_browser_headers`, which protects form posts from cross site forgery.

Currently, the `:api` pipeline only defines `plug :accepts, ["json"]`.

The router invokes a pipeline on a route defined within a scope. Routes outside of a scope have no pipelines. Although the use of nested scopes is discouraged (see above), if we call `pipe_through` within a nested scope, the router will invoke all `pipe_through`'s from parent scopes, followed by the nested one.

Those are a lot of words bunched up together. Let's take a look at some examples to untangle their meaning.

Here's another look at the router from a newly generated Phoenix application, this time with the api scope uncommented back in and a route added.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

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

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", HelloWeb do
    pipe_through :api

    resources "/reviews", ReviewController
  end
end
```

When the server accepts a request, the request will always first pass through the plugs in our Endpoint, after which it will attempt to match on the path and HTTP verb.

Let's say that the request matches our first route: a GET to `/`. The router will first pipe that request through the `:browser` pipeline - which will fetch the session data, fetch the flash, and execute forgery protection - before it dispatches the request to the `PageController` `index` action.

Conversely, if the request matches any of the routes defined by the `resources/2` macro, the router will pipe it through the `:api` pipeline - which currently does nothing - before it dispatches further to the correct action of the `HelloWeb.ReviewController`.

If no route matches, no pipeline is invoked and a 404 error is raised.

Let's stretch these ideas out a little bit more. What if we need to pipe requests through both `:browser` and one or more custom pipelines? We simply `pipe_through` a list of pipelines, and Phoenix will invoke them in order.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
  ...

  scope "/reviews" do
    pipe_through [:browser, :review_checks, :other_great_stuff]

    resources "/", HelloWeb.ReviewController
  end
end
```

Here's another example with two scopes that have different pipelines:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
  ...

  scope "/", HelloWeb do
    pipe_through :browser

    resources "/posts", PostController
  end

  scope "/reviews", HelloWeb do
    pipe_through [:browser, :review_checks]

    resources "/", ReviewController
  end
end
```

In general, the scoping rules for pipelines behave as you might expect. In this example, all routes will pipe through the `:browser` pipeline. However, only the `reviews` resources routes will  pipe through the `:review_checks` pipeline. Since we declared both pipes `pipe_through [:browser, :review_checks]` in a list of pipelines, Phoenix will `pipe_through` each of them as it invokes them in order.

### Creating New Pipelines

Phoenix allows us to create our own custom pipelines anywhere in the router. To do so, we call the `pipeline/2` macro with these arguments: an atom for the name of our new pipeline and a block with all the plugs we want in it.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :review_checks do
    plug :ensure_authenticated_user
    plug :ensure_user_owns_review
  end

  scope "/reviews", HelloWeb do
    pipe_through [:browser, :review_checks]

    resources "/", ReviewController
  end
end
```

Note that pipelines themselves are plugs, so we can plug a pipeline inside another pipeline. For example, we could rewrite the `review_checks` pipeline above to automatically invoke `browser`, simplifying the downstream pipeline call:

```elixir
  pipeline :review_checks do
    plug :browser
    plug :ensure_authenticated_user
    plug :ensure_user_owns_review
  end

  scope "/reviews", HelloWeb do
    pipe_through [:review_checks]

    resources "/", ReviewController
  end
```

## Forward

The `Phoenix.Router.forward/4` macro can be used to send all requests that start with a particular path to a particular plug. Let's say we have a part of our system that is responsible (it could even be a separate application or library) for running jobs in the background, it could have its own web interface for checking the status of the jobs. We can forward to this admin interface using:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  ...

  scope "/", HelloWeb do
    ...
  end

  forward "/jobs", BackgroundJob.Plug
end
```

This means that all routes starting with `/jobs` will be sent to the `HelloWeb.BackgroundJob.Plug` module. Inside the plug, you can match on subroutes, such as `/pending` and `/active` that shows the status of certain jobs.

We can even mix the `forward/4` macro with pipelines. If we wanted to ensure that the user was authenticated and an administrator in order to see the jobs page, we could use the following in our router.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  ...

  scope "/" do
    pipe_through [:authenticate_user, :ensure_admin]
    forward "/jobs", BackgroundJob.Plug
  end
end
```

This means the plugs in the `authenticate_user` and `ensure_admin` pipelines will be called before the `BackgroundJob.Plug` allowing them to send an appropriate response and halt the request accordingly.

The `opts` that are received in the `init/1` callback of the Module Plug can be passed as a 3rd argument. For example, maybe the background job lets you set the name of your application to be displayed on the page. This could be passed with:

```elixir
forward "/jobs", BackgroundJob.Plug, name: "Hello Phoenix"
```

There is a fourth `router_opts` argument that can be passed. These options are outlined in the `Phoenix.Router.scope/2` documentation.

`BackgroundJob.Plug` can be implemented as any Module Plug discussed [in the Plug guide](plug.html). Note though it is not advised to forward to another Phoenix endpoint. This is because plugs defined by your app and the forwarded endpoint would be invoked twice, which may lead to errors.

## Summary

Routing is a big topic, and we have covered a lot of ground here. The important points to take away from this guide are:

- Routes which begin with an HTTP verb name expand to a single clause of the match function.
- Routes which begin with 'resources' expand to 8 clauses of the match function.
- Resources may restrict the number of match function clauses by using the `only:` or `except:` options.
- Any of these routes may be nested.
- Any of these routes may be scoped to a given path.
- Using the `as:` option in a scope can reduce duplication.
- Using the helper option for scoped routes eliminates unreachable paths.
