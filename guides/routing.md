# Routing

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Request life-cycle guide](request_lifecycle.html).

Routers are the main hubs of Phoenix applications. They match HTTP requests to controller actions, wire up real-time channel handlers, and define a series of pipeline transformations scoped to a set of routes.

The router file that Phoenix generates, `lib/hello_web/router.ex`, will look something like this one:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloWeb do
  #   pipe_through :api
  # end

  # ...
end
```

Both the router and controller module names will be prefixed with the name you gave your application suffixed with `Web`.

The first line of this module, `use HelloWeb, :router`, simply makes Phoenix router functions available in our particular router.

Scopes have their own section in this guide, so we won't spend time on the `scope "/", HelloWeb do` block here. The `pipe_through :browser` line will get a full treatment in the "Pipelines" section of this guide. For now, you only need to know that pipelines allow a set of plugs to be applied to different sets of routes.

Inside the scope block, however, we have our first actual route:

```elixir
get "/", PageController, :home
```

`get` is a Phoenix macro that corresponds to the HTTP verb GET. Similar macros exist for other HTTP verbs, including POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE, and HEAD.

> #### Why the macros? {: .info}
>
> Phoenix does its best to keep the usage of macros low. You may have noticed, however, that the `Phoenix.Router` relies heavily on macros. Why is that?
>
> We use `get`, `post`, `put`, and `delete` to define your routes. We use macros for two purposes:
>
>   * They define the routing engine, used on every request, to choose which controller to dispatch the request to. Thanks to macros, Phoenix compiles all of your routes to a huge case-statement with pattern matching rules, which is heavily optimized by the Erlang VM
>
>   * For each route you define, we also define metadata to implement `Phoenix.VerifiedRoutes`. As we will soon learn, verified routes allow us to reference any route as if it were a plain looking string, except that it is verified by the compiler to be valid (making it much harder to ship broken links, forms, mails, etc to production)
>
> In other words, the router relies on macros to build applications that are faster and safer. Also remember that macros in Elixir are compile-time only, which gives plenty of stability after the code is compiled. As we will learn next, Phoenix also provides introspection for all defined routes via `mix phx.routes`.

## Examining routes

Phoenix provides an excellent tool for investigating routes in an application: `mix phx.routes`.

Let's see how this works. Go to the root of a newly-generated Phoenix application and run `mix phx.routes`. You should see something like the following, generated with all routes you currently have:

```console
$ mix phx.routes
GET  /  HelloWeb.PageController :home
...
```

The route above tells us that any HTTP GET request for the root of the application will be handled by the `home` action of the `HelloWeb.PageController`.

## Resources

The router supports other macros besides those for HTTP verbs like [`get`](`Phoenix.Router.get/3`), [`post`](`Phoenix.Router.post/3`), and [`put`](`Phoenix.Router.put/3`). The most important among them is [`resources`](`Phoenix.Router.resources/4`). Let's add a resource to our `lib/hello_web/router.ex` file like this:

```elixir
scope "/", HelloWeb do
  pipe_through :browser

  get "/", PageController, :home
  resources "/users", UserController
  ...
end
```

For now it doesn't matter that we don't actually have a `HelloWeb.UserController`.

Run `mix phx.routes` once again at the root of your project. You should see something like the following:

```console
...
GET     /users           HelloWeb.UserController :index
GET     /users/:id/edit  HelloWeb.UserController :edit
GET     /users/new       HelloWeb.UserController :new
GET     /users/:id       HelloWeb.UserController :show
POST    /users           HelloWeb.UserController :create
PATCH   /users/:id       HelloWeb.UserController :update
PUT     /users/:id       HelloWeb.UserController :update
DELETE  /users/:id       HelloWeb.UserController :delete
...
```

This is the standard matrix of HTTP verbs, paths, and controller actions. For a while, this was known as RESTful routes, but most consider this a misnomer nowadays. Let's look at them individually.

- A GET request to `/users` will invoke the `index` action to show all the users.
- A GET request to `/users/:id/edit` will invoke the `edit` action with an ID to retrieve an individual user from the data store and present the information in a form for editing.
- A GET request to `/users/new` will invoke the `new` action to present a form for creating a new user.
- A GET request to `/users/:id` will invoke the `show` action with an id to show an individual user identified by that ID.
- A POST request to `/users` will invoke the `create` action to save a new user to the data store.
- A PATCH request to `/users/:id` will invoke the `update` action with an ID to save the updated user to the data store.
- A PUT request to `/users/:id` will also invoke the `update` action with an ID to save the updated user to the data store.
- A DELETE request to `/users/:id` will invoke the `delete` action with an ID to remove the individual user from the data store.

If we don't need all these routes, we can be selective using the `:only` and `:except` options to filter specific actions.

Let's say we have a read-only posts resource. We could define it like this:

```elixir
resources "/posts", PostController, only: [:index, :show]
```

Running `mix phx.routes` shows that we now only have the routes to the index and show actions defined.

```console
GET     /posts      HelloWeb.PostController :index
GET     /posts/:id  HelloWeb.PostController :show
```

Similarly, if we have a comments resource, and we don't want to provide a route to delete one, we could define a route like this.

```elixir
resources "/comments", CommentController, except: [:delete]
```

Running `mix phx.routes` now shows that we have all the routes except the DELETE request to the delete action.

```console
GET    /comments           HelloWeb.CommentController :index
GET    /comments/:id/edit  HelloWeb.CommentController :edit
GET    /comments/new       HelloWeb.CommentController :new
GET    /comments/:id       HelloWeb.CommentController :show
POST   /comments           HelloWeb.CommentController :create
PATCH  /comments/:id       HelloWeb.CommentController :update
PUT    /comments/:id       HelloWeb.CommentController :update
```

The `Phoenix.Router.resources/4` macro describes additional options for customizing resource routes.

## Verified Routes

Phoenix includes `Phoenix.VerifiedRoutes` module which provides compile-time checks of router paths against your router by using the `~p` sigil. For example, you can write paths in controllers, tests, and templates and the compiler will make sure those actually match routes defined in your router.

Let's see it in action. Run `iex -S mix` at the root of the project. We'll define a throwaway example module that builds a couple `~p` route paths.

```elixir
iex> defmodule RouteExample do
...>   use HelloWeb, :verified_routes
...>
...>   def example do
...>     ~p"/comments"
...>     ~p"/unknown/123"
...>   end
...> end
warning: no route path for HelloWeb.Router matches "/unknown/123"
  iex:5: RouteExample.example/0

{:module, RouteExample, ...}
iex>
```

Notice how the first call to an existing route, `~p"/comments"` gave no warning, but a bad route path `~p"/unknown/123"` produced a compiler warning, just as it should. This is significant because it allows us to write otherwise hard-coded paths in our application and the compiler will let us know whenever we write a bad route or change our routing structure.

Phoenix projects are set up out of the box to allow use of verified routes throughout your web layer, including tests. For example in your templates you can render `~p` links:

```heex
<.link href={~p"/"}>Welcome Page!</.link>
<.link href={~p"/comments"}>View Comments</.link>
```

Or in a controller, issue a redirect:

```elixir
redirect(conn, to: ~p"/comments/#{comment}")
```

Using `~p` for route paths ensures our application paths and URLs stay up to date with the router definitions. The compiler will catch bugs for us, and let us know when we change routes that are referenced elsewhere in our application.

### More on verified routes

What about paths with query strings? You can add query string key values directly, as a keyword list or map of values, for example:

```elixir
~p"/users/17?admin=true&active=false"
"/users/17?admin=true&active=false"

~p"/users/17?#{[admin: true]}"
"/users/17?admin=true"

~p"/users/17?#{%{admin: true}}"
"/users/17?admin=true"
```

What if we need a full URL instead of a path? Just wrap your path with a call to `Phoenix.VerifiedRoutes.url/1`, which is imported everywhere that `~p` is available:

```elixir
url(~p"/users")
"http://localhost:4000/users"
```

The `url` calls will get the host, port, proxy port, and SSL information needed to construct the full URL from the configuration parameters set for each environment. We'll talk about configuration in more detail in its own guide. For now, you can take a look at `config/dev.exs` file in your own project to see those values.

## Nested resources

It is also possible to nest resources in a Phoenix router. Let's say we also have a `posts` resource that has a many-to-one relationship with `users`. That is to say, a user can create many posts, and an individual post belongs to only one user. We can represent that by adding a nested route in `lib/hello_web/router.ex` like this:

```elixir
resources "/users", UserController do
  resources "/posts", PostController
end
```

When we run `mix phx.routes` now, in addition to the routes we saw for `users` above, we get the following set of routes:

```console
...
GET     /users/:user_id/posts           HelloWeb.PostController :index
GET     /users/:user_id/posts/:id/edit  HelloWeb.PostController :edit
GET     /users/:user_id/posts/new       HelloWeb.PostController :new
GET     /users/:user_id/posts/:id       HelloWeb.PostController :show
POST    /users/:user_id/posts           HelloWeb.PostController :create
PATCH   /users/:user_id/posts/:id       HelloWeb.PostController :update
PUT     /users/:user_id/posts/:id       HelloWeb.PostController :update
DELETE  /users/:user_id/posts/:id       HelloWeb.PostController :delete
...
```

We see that each of these routes scopes the posts to a user ID. For the first one, we will invoke `PostController`'s `index` action, but we will pass in a `user_id`. This implies that we would display all the posts for that individual user only. The same scoping applies for all these routes.

When building paths for nested routes, we will need to interpolate the IDs where they belong in route definition. For the following `show` route, `42` is the `user_id`, and `17` is the `post_id`.

```elixir
user_id = 42
post_id = 17
~p"/users/#{user_id}/posts/#{post_id}"
"/users/42/posts/17"
```

Verified routes also support the `Phoenix.Param` protocol, but we don't need to concern ourselves with Elixir protocols just yet. Just know that once we start building our application with structs like `%User{}` and `%Post{}`, we'll be able to interpolate those data structures directly into our `~p` paths and Phoenix will pluck out the correct fields to use in the route.

```elixir
~p"/users/#{user}/posts/#{post}"
"/users/42/posts/17"
```

Notice how we didn't need to interpolate `user.id` or `post.id`? This is particularly nice if we decide later we want to make our URLs a little nicer and start using slugs instead. We don't need to change any of our `~p`'s!

## Scoped routes

Scopes are a way to group routes under a common path prefix and scoped set of plugs. We might want to do this for admin functionality, APIs, and especially for versioned APIs. Let's say we have user-generated reviews on a site, and that those reviews first need to be approved by an administrator. The semantics of these resources are quite different, and they might not share the same controller. Scopes enable us to segregate these routes.

The paths to the user-facing reviews would look like a standard resource.

```console
/reviews
/reviews/1234
/reviews/1234/edit
...
```

The administration review paths can be prefixed with `/admin`.

```console
/admin/reviews
/admin/reviews/1234
/admin/reviews/1234/edit
...
```

We accomplish this with a scoped route that sets a path option to `/admin` like this one. We can nest this scope inside another scope, but instead, let's set it by itself at the root, by adding to `lib/hello_web/router.ex` the following:

```elixir
scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

We define a new scope where all routes are prefixed with `/admin` and all controllers are under the `HelloWeb.Admin` namespace.

Running `mix phx.routes` again, in addition to the previous set of routes we get the following:

```console
...
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
...
```

This looks good, but there is a problem here. Remember that we wanted both user-facing review routes `/reviews` and the admin ones `/admin/reviews`. If we now include the user-facing reviews in our router under the root scope like this:

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

and we run `mix phx.routes`, we get output for each scoped route:

```console
...
GET     /reviews                 HelloWeb.ReviewController :index
GET     /reviews/:id/edit        HelloWeb.ReviewController :edit
GET     /reviews/new             HelloWeb.ReviewController :new
GET     /reviews/:id             HelloWeb.ReviewController :show
POST    /reviews                 HelloWeb.ReviewController :create
PATCH   /reviews/:id             HelloWeb.ReviewController :update
PUT     /reviews/:id             HelloWeb.ReviewController :update
DELETE  /reviews/:id             HelloWeb.ReviewController :delete
...
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
```

What if we had a number of resources that were all handled by admins? We could put all of them inside the same scope like this:

```elixir
scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/images",  ImageController
  resources "/reviews", ReviewController
  resources "/users",   UserController
end
```

Here's what `mix phx.routes` tells us:

```console
...
GET     /admin/images            HelloWeb.Admin.ImageController :index
GET     /admin/images/:id/edit   HelloWeb.Admin.ImageController :edit
GET     /admin/images/new        HelloWeb.Admin.ImageController :new
GET     /admin/images/:id        HelloWeb.Admin.ImageController :show
POST    /admin/images            HelloWeb.Admin.ImageController :create
PATCH   /admin/images/:id        HelloWeb.Admin.ImageController :update
PUT     /admin/images/:id        HelloWeb.Admin.ImageController :update
DELETE  /admin/images/:id        HelloWeb.Admin.ImageController :delete
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
GET     /admin/users             HelloWeb.Admin.UserController :index
GET     /admin/users/:id/edit    HelloWeb.Admin.UserController :edit
GET     /admin/users/new         HelloWeb.Admin.UserController :new
GET     /admin/users/:id         HelloWeb.Admin.UserController :show
POST    /admin/users             HelloWeb.Admin.UserController :create
PATCH   /admin/users/:id         HelloWeb.Admin.UserController :update
PUT     /admin/users/:id         HelloWeb.Admin.UserController :update
DELETE  /admin/users/:id         HelloWeb.Admin.UserController :delete
```

This is great, exactly what we want. Note how every route and controller is properly namespaced.

Scopes can also be arbitrarily nested, but you should do it carefully as nesting can sometimes make our code confusing and less clear. With that said, suppose that we had a versioned API with resources defined for images, reviews, and users. Then technically, we could set up routes for the versioned API like this:

```elixir
scope "/api", HelloWeb.Api do
  pipe_through :api

  scope "/v1", V1 do
    resources "/images",  ImageController
    resources "/reviews", ReviewController
    resources "/users",   UserController
  end
end
```

You can run `mix phx.routes` to see how these definitions will look like.

Interestingly, we can use multiple scopes with the same path as long as we are careful not to duplicate routes. The following router is perfectly fine with two scopes defined for the same path:

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

If we do duplicate a route — which means two routes having the same path — we'll get this familiar warning:

```console
warning: this clause cannot match because a previous clause at line 16 always matches
```

## Pipelines

We have come quite a long way in this guide without talking about one of the first lines we saw in the router: `pipe_through :browser`. It's time to fix that.

Pipelines are a series of plugs that can be attached to specific scopes. If you are not familiar with plugs, we have an [in-depth guide about them](plug.html).

Routes are defined inside scopes and scopes may pipe through multiple pipelines. Once a route matches, Phoenix invokes all plugs defined in all pipelines associated to that route. For example, accessing `/` will pipe through the `:browser` pipeline, consequently invoking all of its plugs.

Phoenix defines two pipelines by default, `:browser` and `:api`, which can be used for a number of common tasks. In turn we can customize them as well as create new pipelines to meet our needs.

### The `:browser` and `:api` pipelines

As their names suggest, the `:browser` pipeline prepares for routes which render requests for a browser, and the `:api` pipeline prepares for routes which produce data for an API.

The `:browser` pipeline has six plugs: The `plug :accepts, ["html"]` defines the accepted request format or formats. `:fetch_session`, which, naturally, fetches the session data and makes it available in the connection. `:fetch_live_flash`, which fetches any flash messages from LiveView and merges them with the controller flash messages. Then, the plug `:put_root_layout` will store the root layout for rendering purposes. Later `:protect_from_forgery` and `:put_secure_browser_headers`, protects form posts from cross-site forgery.

Currently, the `:api` pipeline only defines `plug :accepts, ["json"]`.

The router invokes a pipeline on a route defined within a scope. Routes outside of a scope have no pipelines. Although the use of nested scopes is discouraged (see above the versioned API example), if we call `pipe_through` within a nested scope, the router will invoke all `pipe_through`'s from parent scopes, followed by the nested one.

Those are a lot of words bunched up together. Let's take a look at some examples to untangle their meaning.

Here's another look at the router from a newly generated Phoenix application, this time with the `/api` scope uncommented back in and a route added.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  scope "/api", HelloWeb do
    pipe_through :api

    resources "/reviews", ReviewController
  end
  # ...
end
```

When the server accepts a request, the request will always first pass through the plugs in our endpoint, after which it will attempt to match on the path and HTTP verb.

Let's say that the request matches our first route: a GET to `/`. The router will first pipe that request through the `:browser` pipeline - which will fetch the session data, fetch the flash, and execute forgery protection - before it dispatches the request to `PageController`'s `home` action.

Conversely, suppose the request matches any of the routes defined by the [`resources/2`](`Phoenix.Router.resources/2`) macro. In that case, the router will pipe it through the `:api` pipeline — which currently only performs content negotiation — before it dispatches further to the correct action of the `HelloWeb.ReviewController`.

If no route matches, no pipeline is invoked and a 404 error is raised.

### Creating new pipelines

Phoenix allows us to create our own custom pipelines anywhere in the router. To do so, we call the [`pipeline/2`](`Phoenix.Router.pipeline/2`) macro with these arguments: an atom for the name of our new pipeline and a block with all the plugs we want in it.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug HelloWeb.Authentication
  end

  scope "/reviews", HelloWeb do
    pipe_through [:browser, :auth]

    resources "/", ReviewController
  end
end
```

The above assumes there is a plug called `HelloWeb.Authentication` that performs authentication and is now part of the `:auth` pipeline.

Note that pipelines themselves are plugs, so we can plug a pipeline inside another pipeline. For example, we could rewrite the `auth` pipeline above to automatically invoke `browser`, simplifying the downstream pipeline call:

```elixir
  pipeline :auth do
    plug :browser
    plug :ensure_authenticated_user
    plug :ensure_user_owns_review
  end

  scope "/reviews", HelloWeb do
    pipe_through :auth

    resources "/", ReviewController
  end
```

## How to organize my routes?

In Phoenix, we tend to define several pipelines, that provide specific functionality. For example, the `:browser` and `:api` pipelines are meant to be accessed by specific clients, browsers and http clients respectively.

Perhaps more importantly, it is also very common to define pipelines specific to authentication and authorization. For example, you might have a pipeline that requires all users are authenticated. Another pipeline may enforce only admin users can access certain routes.

Once your pipelines are defined, you reuse the pipelines in the desired scopes, grouping your routes around their pipelines. For example, going back to our reviews example. Let's say anyone can read a review, but only authenticated users can create them. Your routes could look like this:

```elixir
pipeline :browser do
  ...
end

pipeline :auth do
  plug HelloWeb.Authentication
end

scope "/" do
  pipe_through [:browser]

  get "/reviews", PostController, :index
  get "/reviews/:id", PostController, :show
end

scope "/" do
  pipe_through [:browser, :auth]

  get "/reviews/new", PostController, :new
  post "/reviews", PostController, :create
end
```

Note in the above how the routes are split across different scopes. While the separation can be confusing at first, it has one big upside: it is very easy to inspect your routes and see all routes that, for example, require authentication and which ones do not. This helps with auditing and making sure your routes have the proper scope.

You can create as few or as many scopes as you want. Because pipelines are reusable across scopes, they help encapsulate common functionality and you can compose them as necessary on each scope you define.

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

This means that all routes starting with `/jobs` will be sent to the `BackgroundJob.Plug` module. Inside the plug, you can match on subroutes, such as `/pending` and `/active` that shows the status of certain jobs.

We can even mix the [`forward/4`](`Phoenix.Router.forward/4`) macro with pipelines. If we wanted to ensure that the user was authenticated and was an administrator in order to see the jobs page, we could use the following in our router.

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

`BackgroundJob.Plug` can be implemented as any "Module Plug" discussed in the [Plug guide](plug.html). Note though it is not advised to forward to another Phoenix endpoint. This is because plugs defined by your app and the forwarded endpoint would be invoked twice, which may lead to errors.

## Summary

Routing is a big topic, and we have covered a lot of ground here. The important points to take away from this guide are:

- Routes which begin with an HTTP verb name expand to a single clause of the match function.
- Routes declared with `resources` expand to 8 clauses of the match function.
- Resources may restrict the number of match function clauses by using the `only:` or `except:` options.
- Any of these routes may be nested.
- Any of these routes may be scoped to a given path.
- Using verified routes with `~p` for compile-time route checks
