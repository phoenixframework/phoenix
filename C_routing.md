Routers are the main hubs of Phoenix applications. They match HTTP requests to controller actions, wire up real-time channel handlers, and define a series of pipeline transformations for scoping middleware to sets of routes.

The router file that Phoenix generates, `web/router.ex`, will look something like this one:

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
The name you gave your application will appear instead of `HelloPhoenix` for both the router module and controller name.

The first line of this module, `use HelloPhoenix.Web, :router`, simply makes Phoenix router functions available in our particular router.

Scopes have their own section in this guide, so we won't spend time on the `scope "/", HelloPhoenix do` block here. The `pipe_through :browser` line will get a full treatment in the Pipeline section of this guide. For now, you only need to know that pipelines allow a set of middleware transformations to be applied to different sets of routes.

Inside the scope block, however, we have our first actual route:

```elixir
  get "/", PageController, :index
```

`get` is a Phoenix macro which expands out to define one clause of the `match/3` function. It corresponds to the HTTP verb GET. Similar macros exist for other HTTP verbs including POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE and HEAD.

The first argument to these macros is the path. Here, it is the root of the application, `/`. The next two arguments are the controller and action we want to have handle this request. These macros may also take other options, which we will see throughout the rest of this guide.

If this were the only route in our router module, the clause of the `match/3` function would look like this after the macro is expanded:

```elixir
  def match(conn, "GET", ["/"])
```

The body of the `match/3` function sets up the connection and invokes the matched controller action.

As we add more routes, more clauses of the match function will be added to our router module. These will behave like any other multi-clause function in Elixir. They will be tried in order from the top, and the first clause to match the parameters given (verb and path) will be executed. After a match is found, the search will stop and no other clauses will be tried.

This means that it is possible to create a route which will never match, based on the HTTP verb and the path, regardless of the controller and action.

If we do create an ambiguous route, the router will still compile, but we will get a warning. Let's see this in action.

Define this route at the bottom of the `scope "/", HelloPhoenix do` block in the router.

```elixir
get "/", RootController, :index
```

Then run `$ mix compile` at the root of your project. You will see the following warning from the compiler:

```text
web/router.ex:1: warning: this clause cannot match because a previous clause at line 1 always matches
Compiled web/router.ex
```

### Examining Routes

Phoenix provides a great tool for investigating routes in an application, the mix task `phoenix.routes`.

Let's see how this works. Go to the root of a newly-generated Phoenix application and run `$ mix phoenix.routes`. (If you haven't already done so, you'll need to run `$ mix do deps.get, compile` before running the `routes` task.) You should see something like the following, generated from the only route we currently have:

```console
$ mix phoenix.routes
page_path  GET  /  HelloPhoenix.PageController :index
```
The output tells us that any HTTP GET request for the root of the application will be handled by the `index` action of the `HelloPhoenix.PageController`.

`page_path` is an example of what Phoenix calls a path helper, and we'll talk about those very soon.

### Resources

The router supports other macros besides those for HTTP verbs like `get`, `post`, and `put`. The most important among them is `resources`, which expands out to eight clauses of the `match/3` function.

Let's add a resource to our `web/router.ex` file like this:

```elixir
scope "/", HelloPhoenix do
  pipe_through :browser # Use the default browser stack

  get "/", PageController, :index
  resources "/users", UserController
end
```
For this purpose, it doesn't matter that we don't actually have a `HelloPhoenix.UserController`.

Then go to the root of your project, and run `$ mix phoenix.routes`

You should see something like the following:

```elixir
user_path  GET     /users           HelloPhoenix.UserController :index
user_path  GET     /users/:id/edit  HelloPhoenix.UserController :edit
user_path  GET     /users/new       HelloPhoenix.UserController :new
user_path  GET     /users/:id       HelloPhoenix.UserController :show
user_path  POST    /users           HelloPhoenix.UserController :create
user_path  PATCH   /users/:id       HelloPhoenix.UserController :update
           PUT     /users/:id       HelloPhoenix.UserController :update
user_path  DELETE  /users/:id       HelloPhoenix.UserController :delete
```

Of course, the name of your project will replace `HelloPhoenix`.

This is the standard matrix of HTTP verbs, paths, and controller actions. Let's look at them individually, in a slightly different order.

- A GET request to `/users` will invoke the `index` action to show all the users.
- A GET request to `/users/:id` will invoke the `show` action with an id to show an individual user identified by that ID.
- A GET request to `/users/new` will invoke the `new` action to present a form for creating a new user.
- A POST request to `/users` will invoke the `create` action to save a new user to the data store.
- A GET request to `/users/:id/edit` will invoke the `edit` action with an ID to retrieve an individual user from the data store and present the information in a form for editing.
- A PATCH request to `/users/:id` will invoke the `update` action with an ID to save the updated user to the data store.
- A PUT request to `/users/:id` will also invoke the `update` action with an ID to save the updated user to the data store.
- A DELETE request to `/users/:id` will invoke the `delete` action with an ID to remove the individual user from the data store.

If we don't feel that we need all of these routes, we can be selective using the `:only` and `:except` options.

Let's say we have a read-only posts resource. We could define it like this:

```elixir
resources "/posts", PostController, only: [:index, :show]
```

Running `$ mix phoenix.routes` shows that we now only have the routes to the index and show actions defined.

```elixir
post_path  GET     /posts HelloPhoenix.PostController :index
post_path  GET     /posts/:id HelloPhoenix.PostController :show
```

Similarly, if we have a comments resource, and we don't want to provide a route to delete one, we could define a route like this.

```elixir
resources "/comments", CommentController, except: [:delete]
```

Running `$ mix phoenix.routes` now shows that we have all the routes except the DELETE request to the delete action.

```elixir
comment_path  GET     /comments HelloPhoenix.CommentController :index
comment_path  GET     /comments/:id/edit HelloPhoenix.CommentController :edit
comment_path  GET     /comments/new HelloPhoenix.CommentController :new
comment_path  GET     /comments/:id HelloPhoenix.CommentController :show
comment_path  POST    /comments HelloPhoenix.CommentController :create
comment_path  PATCH   /comments/:id HelloPhoenix.CommentController :update
              PUT     /comments/:id HelloPhoenix.CommentController :update
```
### Path Helpers

Path helpers are functions which are dynamically defined on the `Router.Helpers` module for an individual application. For us, that is `HelloPhoenix.Router.Helpers`.  Their names are derived from the name of the controller used in the route definition. Our controller is `HelloPhoenix.PageController`, and `page_path` is the function which will return the path to the root of our application.

That's a mouthful. Let's see it in action. Run `$ iex -S mix` at the root of the project. When we call the `page_path` function on our router helpers with the `Endpoint` or connection and action as arguments, it returns the path to us.

```elixir
iex> HelloPhoenix.Router.Helpers.page_path(HelloPhoenix.Endpoint, :index)
"/"
```

This is significant because we can use the `page_path` function in a template to link to the root of our application. Note: If that function invocation seems uncomfortably long, there is a solution, including `import HelloPhoenix.Router.Helpers` in our main application view.

```html
<a href="<%= page_path(@conn, :index) %>">To the Welcome Page!</a>
```
Please see the [View Guide](http://www.phoenixframework.org/docs/views) for more information.

This pays off tremendously if we should ever have to change the path of our route in the router. Since the path helpers are built dynamically from the routes, any calls to `page_path` in our templates will still work.

### More on Path Helpers

When we ran the `phoenix.routes` task for our user resource, it listed the `user_path` as the path helper function for each line of output. Here is what that translates to for each action:

```elixir
iex> import HelloPhoenix.Router.Helpers
iex> alias HelloPhoenix.Endpoint
iex> user_path(Endpoint, :index)
"/users"

iex> user_path(Endpoint, :show, 17)
"/users/17"

iex> user_path(Endpoint, :new)
"/users/new"

iex> user_path(Endpoint, :create)
"/users"

iex> user_path(Endpoint, :edit, 37)
"/users/37/edit"

iex> user_path(Endpoint, :update, 37)
"/users/37"

iex> user_path(Endpoint, :delete, 17)
"/users/17"
```

What about paths with query strings? By adding an optional fourth argument of key value pairs, the path helpers will return those pairs in the query string.

```elixir
iex> user_path(Endpoint, :show, 17, admin: true, active: false)
"/users/17?admin=true&active=false"
```

What if we need a full url instead of a path? Just replace `_path` by `_url`:

```elixir
iex(3)> user_url(Endpoint, :index)
"http://localhost:4000/users"
```
Application endpoints will have their own guide soon. For now, think of them as the entity that handles requests just up to the point where the router takes over. That includes starting the app/server, applying configuration, and applying the plugs common to all requests.

The `_url` functions will get the host, port, proxy port, and SSL information needed to construct the full URL from the configuration parameters set for each environment. We'll talk about configuration in more detail in its own guide. For now, you can take a look at `/config/dev.exs` file in your own project to see those values.

### Nested Resources

It is also possible to nest resources in a Phoenix router. Let's say we also have a `posts` resource which has a one to many relationship with `users`. That is to say, a user can create many posts, and an individual post belongs to only one user. We can represent that by adding a nested route in `web/router.ex` like this:

```elixir
resources "/users", UserController do
  resources "/posts", PostController
end
```
When we run `$ mix phoenix.routes` now, in addition to the routes we saw for `users` above, we get the following set of routes:

```elixir
. . .
user_post_path  GET     users/:user_id/posts HelloPhoenix.PostController :index
user_post_path  GET     users/:user_id/posts/:id/edit HelloPhoenix.PostController :edit
user_post_path  GET     users/:user_id/posts/new HelloPhoenix.PostController :new
user_post_path  GET     users/:user_id/posts/:id HelloPhoenix.PostController :show
user_post_path  POST    users/:user_id/posts HelloPhoenix.PostController :create
user_post_path  PATCH   users/:user_id/posts/:id HelloPhoenix.PostController :update
                PUT     users/:user_id/posts/:id HelloPhoenix.PostController :update
user_post_path  DELETE  users/:user_id/posts/:id HelloPhoenix.PostController :delete
```

We see that each of these routes scopes the posts to a user ID. For the first one, we will invoke the `PostController` `index` action, but we will pass in a `user_id`. This implies that we would display all the posts for that individual user only. The same scoping applies for all these routes.

When calling path helper functions for nested routes, we will need to pass the IDs in the order they came in the route definition. For the following `show` route, `42` is the `user_id`, and `17` is the `post_id`. Let's remember to alias our `HelloPhoenix.Endpoint` before we begin.

```elixir
iex> alias HelloPhoenix.Endpoint
iex> HelloPhoenix.Router.Helpers.user_post_path(Endpoint, :show, 42, 17)
"/users/42/posts/17"
```

Again, if we add a key/value pair to the end of the function call, it is added to the query string.

```elixir
iex> HelloPhoenix.Router.Helpers.user_post_path(Endpoint, :index, 42, active: true)
"/users/42/posts?active=true"
```

### Scoped Routes

Scopes are a way to group routes under a common path prefix and scoped set of plug middleware. We might want to do this for admin functionality, APIs, and especially for versioned APIs. Let's say we have user generated reviews on a site, and that those reviews first need to be approved by an admin. The semantics of these resources are quite different, and they might not share the same controller. Scopes enable us to segregate these routes.

The paths to the user facing reviews would look like a standard resource.

```text
/reviews
/reviews/1234
/reviews/1234/edit
. . .
```

The admin review paths could be prefixed with `/admin`.

```text
/admin/reviews
/admin/reviews/1234
/admin/reviews/1234/edit
. . .
```

We accomplish this with a scoped route that sets a path option to `/admin` like this one. For now, let's not nest this scope inside of any other scopes (like the `scope "/", HelloPhoenix do` one provided for us in a new app).

```elixir
scope "/admin" do
  pipe_through :browser

  resources "/reviews", HelloPhoenix.Admin.ReviewController
end
```

Note that Phoenix will assume that the path we set ought to begin with a slash, so `scope "/admin" do` and `scope "admin" do` will both produce the same results.

Note also, that the way this scope is currently defined, we need to fully qualify our controller name, `HelloPhoenix.Admin.ReviewController`. We'll fix that in a minute.

Running `$ mix phoenix.routes` again, in addition to the previous set of routes we get the following:

```elixir
. . .
review_path  GET     /admin/reviews HelloPhoenix.Admin.ReviewController :index
review_path  GET     /admin/reviews/:id/edit HelloPhoenix.Admin.ReviewController :edit
review_path  GET     /admin/reviews/new HelloPhoenix.Admin.ReviewController :new
review_path  GET     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :show
review_path  POST    /admin/reviews HelloPhoenix.Admin.ReviewController :create
review_path  PATCH   /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
             PUT     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
review_path  DELETE  /admin/reviews/:id HelloPhoenix.Admin.ReviewController :delete
```

This looks good, but there is a problem here. Remember that we wanted both user facing reviews routes `/reviews` as well as the admin ones `/admin/reviews`. If we now include the user facing reviews in our router like this:

```elixir
scope "/", HelloPhoenix do
  pipe_through :browser
  . . .
  resources "/reviews", ReviewController
  . . .
end

scope "/admin" do
  resources "/reviews", HelloPhoenix.Admin.ReviewController
end
```

and we run `$ mix phoenix.routes`, we get this output:

```elixir
. . .
review_path  GET     /reviews HelloPhoenix.ReviewController :index
review_path  GET     /reviews/:id/edit HelloPhoenix.ReviewController :edit
review_path  GET     /reviews/new HelloPhoenix.ReviewController :new
review_path  GET     /reviews/:id HelloPhoenix.ReviewController :show
review_path  POST    /reviews HelloPhoenix.ReviewController :create
review_path  PATCH   /reviews/:id HelloPhoenix.ReviewController :update
             PUT     /reviews/:id HelloPhoenix.ReviewController :update
review_path  DELETE  /reviews/:id HelloPhoenix.ReviewController :delete
. . .
review_path  GET     /admin/reviews HelloPhoenix.Admin.ReviewController :index
review_path  GET     /admin/reviews/:id/edit HelloPhoenix.Admin.ReviewController :edit
review_path  GET     /admin/reviews/new HelloPhoenix.Admin.ReviewController :new
review_path  GET     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :show
review_path  POST    /admin/reviews HelloPhoenix.Admin.ReviewController :create
review_path  PATCH   /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
             PUT     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
review_path  DELETE  /admin/reviews/:id HelloPhoenix.Admin.ReviewController :delete
```

The actual routes we get all look right, except for the path helper `review_path` at the beginning of each line. We are getting the same helper for both the user facing review routes and the admin ones, which is not correct. We can fix this problem by adding an `as: :admin` option to our admin scope.

```elixir
scope "/", HelloPhoenix do
  pipe_through :browser
  . . .
  resources "/reviews", ReviewController
  . . .
end

scope "/admin", as: :admin do
  resources "/reviews", HelloPhoenix.Admin.ReviewController
end
```

`$ mix phoenix.routes` now shows us we have what we are looking for.

```elixir
. . .
      review_path  GET     /reviews HelloPhoenix.ReviewController :index
      review_path  GET     /reviews/:id/edit HelloPhoenix.ReviewController :edit
      review_path  GET     /reviews/new HelloPhoenix.ReviewController :new
      review_path  GET     /reviews/:id HelloPhoenix.ReviewController :show
      review_path  POST    /reviews HelloPhoenix.ReviewController :create
      review_path  PATCH   /reviews/:id HelloPhoenix.ReviewController :update
                   PUT     /reviews/:id HelloPhoenix.ReviewController :update
      review_path  DELETE  /reviews/:id HelloPhoenix.ReviewController :delete
. . .
admin_review_path  GET     /admin/reviews HelloPhoenix.Admin.ReviewController :index
admin_review_path  GET     /admin/reviews/:id/edit HelloPhoenix.Admin.ReviewController :edit
admin_review_path  GET     /admin/reviews/new HelloPhoenix.Admin.ReviewController :new
admin_review_path  GET     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :show
admin_review_path  POST    /admin/reviews HelloPhoenix.Admin.ReviewController :create
admin_review_path  PATCH   /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
                   PUT     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
admin_review_path  DELETE  /admin/reviews/:id HelloPhoenix.Admin.ReviewController :delete
```

The path helpers now return what we want them to as well. Run `$ iex -S mix` and give it a try yourself.

```elixir
iex(1)> HelloPhoenix.Router.Helpers.review_path(Endpoint, :index)
"/reviews"

iex(2)> HelloPhoenix.Router.Helpers.admin_review_path(Endpoint, :show, 1234)
"/admin/reviews/1234"
```

What if we had a number of resources that were all handled by admins? We could put all of them inside the same scope like this:

```elixir
scope "/admin", as: :admin do
  pipe_through :browser

  resources "/images", HelloPhoenix.Admin.ImageController
  resources "/reviews", HelloPhoenix.Admin.ReviewController
  resources "/users", HelloPhoenix.Admin.UserController
end
```

Here's what `$ mix phoenix.routes` tells us:

```elixir
. . .
 admin_image_path  GET     /admin/images HelloPhoenix.Admin.ImageController :index
 admin_image_path  GET     /admin/images/:id/edit HelloPhoenix.Admin.ImageController :edit
 admin_image_path  GET     /admin/images/new HelloPhoenix.Admin.ImageController :new
 admin_image_path  GET     /admin/images/:id HelloPhoenix.Admin.ImageController :show
 admin_image_path  POST    /admin/images HelloPhoenix.Admin.ImageController :create
 admin_image_path  PATCH   /admin/images/:id HelloPhoenix.Admin.ImageController :update
                   PUT     /admin/images/:id HelloPhoenix.Admin.ImageController :update
 admin_image_path  DELETE  /admin/images/:id HelloPhoenix.Admin.ImageController :delete
admin_review_path  GET     /admin/reviews HelloPhoenix.Admin.ReviewController :index
admin_review_path  GET     /admin/reviews/:id/edit HelloPhoenix.Admin.ReviewController :edit
admin_review_path  GET     /admin/reviews/new HelloPhoenix.Admin.ReviewController :new
admin_review_path  GET     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :show
admin_review_path  POST    /admin/reviews HelloPhoenix.Admin.ReviewController :create
admin_review_path  PATCH   /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
                   PUT     /admin/reviews/:id HelloPhoenix.Admin.ReviewController :update
admin_review_path  DELETE  /admin/reviews/:id HelloPhoenix.Admin.ReviewController :delete
  admin_user_path  GET     /admin/users HelloPhoenix.Admin.UserController :index
  admin_user_path  GET     /admin/users/:id/edit HelloPhoenix.Admin.UserController :edit
  admin_user_path  GET     /admin/users/new HelloPhoenix.Admin.UserController :new
  admin_user_path  GET     /admin/users/:id HelloPhoenix.Admin.UserController :show
  admin_user_path  POST    /admin/users HelloPhoenix.Admin.UserController :create
  admin_user_path  PATCH   /admin/users/:id HelloPhoenix.Admin.UserController :update
                   PUT     /admin/users/:id HelloPhoenix.Admin.UserController :update
  admin_user_path  DELETE  /admin/users/:id HelloPhoenix.Admin.UserController :delete
```

This is great, exactly what we want, but we can make it even better. Notice that for each resource, we needed to fully qualify the controller name by prefixing it with `HelloPhoenix.Admin`. That's tedious and error prone. Assuming that the name of each controller begins with `HelloPhoenix.Admin`, then we can add a `HelloPhoenix.Admin` option to our scope declaration just after the scope path, and all of our routes will have the correct, fully qualified controller name.

```elixir
scope "/admin", HelloPhoenix.Admin, as: :admin do
  pipe_through :browser

  resources "/images",  ImageController
  resources "/reviews", ReviewController
  resources "/users",   UserController
end
```

Now run `$ mix phoenix.routes` again and you can see that we get the same result as above when we qualified each controller name individually.

As an extra bonus, we could nest all of the routes for our application inside a scope that simply has an alias for the name of our Phoenix app, and eliminate the duplication in our controller names.

Phoenix already does this now for us in the generated router for a new application (see beginning of this section). Notice here the use of `HelloPhoenix.Router` in the `defmodule` declaration:

```elixir
defmodule HelloPhoenix.Router do
  use HelloPhoenix.Web, :router

  scope "/", HelloPhoenix do
    pipe_through :browser

    get "/images", ImageController, :index
    resources "/reviews", ReviewController
    resources "/users",   UserController
  end
end
```

Again `$ mix phoenix.routes` tells us that all of our controllers now have the correct, fully-qualified names.

```elixir
image_path   GET     /images            HelloPhoenix.ImageController :index
review_path  GET     /reviews           HelloPhoenix.ReviewController :index
review_path  GET     /reviews/:id/edit  HelloPhoenix.ReviewController :edit
review_path  GET     /reviews/new       HelloPhoenix.ReviewController :new
review_path  GET     /reviews/:id       HelloPhoenix.ReviewController :show
review_path  POST    /reviews           HelloPhoenix.ReviewController :create
review_path  PATCH   /reviews/:id       HelloPhoenix.ReviewController :update
             PUT     /reviews/:id       HelloPhoenix.ReviewController :update
review_path  DELETE  /reviews/:id       HelloPhoenix.ReviewController :delete
  user_path  GET     /users             HelloPhoenix.UserController :index
  user_path  GET     /users/:id/edit    HelloPhoenix.UserController :edit
  user_path  GET     /users/new         HelloPhoenix.UserController :new
  user_path  GET     /users/:id         HelloPhoenix.UserController :show
  user_path  POST    /users             HelloPhoenix.UserController :create
  user_path  PATCH   /users/:id         HelloPhoenix.UserController :update
             PUT     /users/:id         HelloPhoenix.UserController :update
  user_path  DELETE  /users/:id         HelloPhoenix.UserController :delete
```

Although technically scopes can also be nested (just like resources), the use of nested scopes is generally discouraged because it can sometimes make our code confusing and less clear. With that said, suppose that we had a versioned API with resources defined for images, reviews and users. Then technically we could  setup routes for the versioned API like this:

```elixir
scope "/api", HelloPhoenix.Api, as: :api do
  pipe_through :api

  scope "/v1", V1, as: :v1 do
    resources "/images",  ImageController
    resources "/reviews", ReviewController
    resources "/users",   UserController
  end
end
```

`$ mix phoenix.routes` tells us that we have the routes we're looking for.

```elixir
 api_v1_image_path  GET     /api/v1/images HelloPhoenix.Api.V1.ImageController :index
 api_v1_image_path  GET     /api/v1/images/:id/edit HelloPhoenix.Api.V1.ImageController :edit
 api_v1_image_path  GET     /api/v1/images/new HelloPhoenix.Api.V1.ImageController :new
 api_v1_image_path  GET     /api/v1/images/:id HelloPhoenix.Api.V1.ImageController :show
 api_v1_image_path  POST    /api/v1/images HelloPhoenix.Api.V1.ImageController :create
 api_v1_image_path  PATCH   /api/v1/images/:id HelloPhoenix.Api.V1.ImageController :update
                    PUT     /api/v1/images/:id HelloPhoenix.Api.V1.ImageController :update
 api_v1_image_path  DELETE  /api/v1/images/:id HelloPhoenix.Api.V1.ImageController :delete
api_v1_review_path  GET     /api/v1/reviews HelloPhoenix.Api.V1.ReviewController :index
api_v1_review_path  GET     /api/v1/reviews/:id/edit HelloPhoenix.Api.V1.ReviewController :edit
api_v1_review_path  GET     /api/v1/reviews/new HelloPhoenix.Api.V1.ReviewController :new
api_v1_review_path  GET     /api/v1/reviews/:id HelloPhoenix.Api.V1.ReviewController :show
api_v1_review_path  POST    /api/v1/reviews HelloPhoenix.Api.V1.ReviewController :create
api_v1_review_path  PATCH   /api/v1/reviews/:id HelloPhoenix.Api.V1.ReviewController :update
                    PUT     /api/v1/reviews/:id HelloPhoenix.Api.V1.ReviewController :update
api_v1_review_path  DELETE  /api/v1/reviews/:id HelloPhoenix.Api.V1.ReviewController :delete
  api_v1_user_path  GET     /api/v1/users HelloPhoenix.Api.V1.UserController :index
  api_v1_user_path  GET     /api/v1/users/:id/edit HelloPhoenix.Api.V1.UserController :edit
  api_v1_user_path  GET     /api/v1/users/new HelloPhoenix.Api.V1.UserController :new
  api_v1_user_path  GET     /api/v1/users/:id HelloPhoenix.Api.V1.UserController :show
  api_v1_user_path  POST    /api/v1/users HelloPhoenix.Api.V1.UserController :create
  api_v1_user_path  PATCH   /api/v1/users/:id HelloPhoenix.Api.V1.UserController :update
                    PUT     /api/v1/users/:id HelloPhoenix.Api.V1.UserController :update
  api_v1_user_path  DELETE  /api/v1/users/:id HelloPhoenix.Api.V1.UserController :delete
```
Interestingly, we can use multiple scopes with the same path as long as we are careful not to duplicate routes. If we do duplicate a route, we'll get this familiar warning.

```console
warning: this clause cannot match because a previous clause at line 16 always matches
```
This router is perfectly fine with two scopes defined for the same path.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router
  . . .
  scope "/", HelloPhoenix do
    pipe_through :browser

    resources "/users", UserController
  end

  scope "/", AnotherApp do
    pipe_through :browser

    resources "/posts", PostController
  end
  . . .
end
```
And when we run `$ mix phoenix.routes`, we see the following output.

```elixir
user_path  GET     /users           HelloPhoenix.UserController :index
user_path  GET     /users/:id/edit  HelloPhoenix.UserController :edit
user_path  GET     /users/new       HelloPhoenix.UserController :new
user_path  GET     /users/:id       HelloPhoenix.UserController :show
user_path  POST    /users           HelloPhoenix.UserController :create
user_path  PATCH   /users/:id       HelloPhoenix.UserController :update
           PUT     /users/:id       HelloPhoenix.UserController :update
user_path  DELETE  /users/:id       HelloPhoenix.UserController :delete
post_path  GET     /posts           AnotherApp.PostController :index
post_path  GET     /posts/:id/edit  AnotherApp.PostController :edit
post_path  GET     /posts/new       AnotherApp.PostController :new
post_path  GET     /posts/:id       AnotherApp.PostController :show
post_path  POST    /posts           AnotherApp.PostController :create
post_path  PATCH   /posts/:id       AnotherApp.PostController :update
           PUT     /posts/:id       AnotherApp.PostController :update
post_path  DELETE  /posts/:id       AnotherApp.PostController :delete
```

### Pipelines

We have come quite a long way in this guide without talking about one of the first lines we saw in the router - `pipe_through :browser`. It's time to fix that.

Remember in the [Overview Guide](http://www.phoenixframework.org/docs/overview) when we described plugs as being stacked and executable in a pre-determined order, like a pipeline? Now we're going to take a closer look at how these plug stacks work in the router.

Pipelines are simply plugs stacked up together in a specific order and given a name. They allow us to customize behaviors and transformations related to the handling of requests. Phoenix provides us with some default pipelines for a number of common tasks. In turn we can customize them as well as create new pipelines to meet our needs.

A newly generated Phoenix application defines two pipelines called `:browser` and `:api`. We'll get to those in a minute, but first we need to talk about the plug stack in the Endpoint plugs.

##### The Endpoint Plugs

Endpoints organize all the plugs common to every request, and apply them before dispatching into the router(s) with their underlying `:browser`, `:api`, and custom pipelines. The default Endpoint plugs do quite a lot of work. Here they are in order.

- [Plug.Static](http://hexdocs.pm/plug/Plug.Static.html) - serves static assets. Since this plug comes before the logger, serving of static assets is not logged

- [Plug.Logger](http://hexdocs.pm/plug/Plug.Logger.html) - logs incoming requests

- [Phoenix.CodeReloader](http://hexdocs.pm/phoenix/Phoenix.CodeReloader.html) - a plug that enables code reloading for all entries in the web directory. It is configured directly in the Phoenix application

- [Plug.Parsers](http://hexdocs.pm/plug/Plug.Parsers.html) - parses the request body when a known parser is available. By default parsers urlencoded, multipart and json (with poison). The request body is left untouched when the request content-type cannot be parsed

- [Plug.MethodOverride](http://hexdocs.pm/plug/Plug.MethodOverride.html) - converts the request method to
  PUT, PATCH or DELETE for POST requests with a valid `_method` parameter

- [Plug.Head](http://hexdocs.pm/plug/Plug.Head.html) - converts HEAD requests to GET requests and strips the response body

- [Plug.Session](http://hexdocs.pm/plug/Plug.Session.html) - a plug that sets up session management.
  Note that `fetch_session/2` must still be explicitly called before using the session as this plug just sets up how the session is fetched

- [Plug.Router](http://hexdocs.pm/plug/Plug.Router.html) - plugs a router into the request cycle

##### The `:browser` and `:api` Pipelines

Phoenix defines two other pipelines by default, `:browser` and `:api`. The router will invoke these after it matches a route, assuming we have called `pipe_through/1` with them in the enclosing scope.

As their names suggest, the `:browser` pipeline prepares for routes which render requests for a browser. The `:api` pipeline prepares for routes which produce data for an api.

The `:browser` pipeline has five plugs: `plug :accepts, ["html"]` which defines the request format or formats which will be accepted, `:fetch_session`, which, naturally, fetches the session data and makes it available in the connection, `:fetch_flash` which retrieves any flash messages which may have been set, as well as `:protect_from_forgery` and `:put_secure_browser_headers`, which protects form posts from cross site forgery.

Currently, the `:api` pipeline only defines `plug :accepts, ["json"]`.

The router invokes a pipeline on a route defined within a scope. If no scope is defined, the router will invoke the pipeline on all the routes in the router. Although the use of nested scopes is discouraged (see above), if we call `pipe_through` within a nested scope, the router will invoke all `pipe_through`'s from parent scopes, followed by the nested one.

Those are a lot of words bunched up together. Let's take a look at some examples to untangle their meaning.

Here's another look at the router from a newly generated Phoenix application, this time with the api scope uncommented back in and a route added.

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
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", HelloPhoenix do
    pipe_through :api

    resources "/reviews", ReviewController
  end
end
```

When the server accepts a request, the request will always first pass through the plugs in our Endpoint, after which it will attempt to match on the path and HTTP verb.

Let's say that the request matches our first route: a GET to `/`. The router will first pipe that request through the `:browser` pipeline - which will fetch the session data, fetch the flash, and execute forgery protection - before it dispatches the request to the `PageController` `index` action.

Conversely, if the request matches any of the routes defined by the `resources/2` macro, the router will pipe it through the `:api` pipeline - which currently does nothing - before it dispatches further to the correct action of the `HelloPhoenix.ReviewController`.

If we know that our application only renders views for the browser, we can simplify our router quite a bit by removing the `api` stuff as well as the scopes:

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

  pipe_through :browser

  get "/", HelloPhoenix.PageController, :index

  resources "/reviews", HelloPhoenix.ReviewController
end
```
Removing all scopes forces the router to invoke the `:browser` pipeline on all routes.

Let's stretch these ideas out a little bit more. What if we need to pipe requests through both `:browser` and one or more custom pipelines? We simply `pipe_through` a list of pipelines, and Phoenix will invoke them in order.

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
  ...

  scope "/reviews" do
    # Use the default browser stack.
    pipe_through [:browser, :review_checks, :other_great_stuff]

    resources "/reviews", HelloPhoenix.ReviewController
  end
end
```

Here's another example with two scopes that have different pipelines:

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
  ...

  scope "/", HelloPhoenix do
    pipe_through :browser

    resources "/posts", PostController
  end

  scope "/reviews", HelloPhoenix do
    pipe_through [:browser, :review_checks]

    resources "/reviews", ReviewController
  end
end
```

In general, the scoping rules for pipelines behave as you might expect. In this example, all routes will pipe through the `:browser` pipeline. However, only the `reviews` resources routes will  pipe through the `:review_checks` pipeline. Since we declared both pipes `pipe_through [:browser, :review_checks]` in a list of pipelines, Phoenix will `pipe_through` each of them as it invokes them in order.

##### Creating New Pipelines

Phoenix allows us to create our own custom pipelines anywhere in the router. To do so, we call the `pipeline/2` macro with these arguments: an atom for the name of our new pipeline and a block with all the plugs we want in it.

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

  pipeline :review_checks do
    plug :ensure_authenticated_user
    plug :ensure_user_owns_review
  end

  scope "/reviews", HelloPhoenix do
    pipe_through :review_checks

    resources "/reviews", ReviewController
  end
end
```

### Channel Routes

Channels are a very exciting, real-time component of the Phoenix framework. Channels handle incoming and outgoing messages broadcast over a socket for a given topic. Channel routes, then, need to match requests by socket and topic in order to dispatch to the correct channel. (For a more detailed description of channels and their behavior, please see the [Channel Guide](http://www.phoenixframework.org/docs/channels).)

We mount socket handlers in our endpoint at `lib/hello_phoenix/endpoint.ex`. Socket handlers take care of authentication callbacks and channel routes.

```elixir
defmodule HelloPhoenix.Endpoint do
  use Phoenix.Endpoint

  socket "/socket", HelloPhoenix.UserSocket
  ...
end
```

Next, we need to open our `web/channels/user_socket.ex` file and use the `channel/3` macro to define our channel routes. The routes will match a topic pattern to a channel to handle events. If we have a channel module called `RoomChannel` and a topic called `"rooms:*"`, the code to do this is straightforward.

```elixir
defmodule HelloPhoenix.UserSocket do
  use Phoenix.Socket

  channel "rooms:*", HelloPhoenix.RoomChannel
  ...
end
```

Topics are just string identifiers. The form we are using here is a convention which allows us to define topics and subtopics in the same string - "topic:subtopic". The `*` is a wildcard character which allows us to match on any subtopic, so `"rooms:lobby"` and `"rooms:kitchen"` would both match this route.

Phoenix abstracts the socket transport layer and includes two transport mechanisms out of the box - WebSockets and Long-Polling. If we wanted to make sure that our channel is handled by only one type of transport, we could specify that using the `via` option, like this.

```elixir
channel "rooms:*", HelloPhoenix.RoomChannel, via: [Phoenix.Transports.WebSocket]
```

Each socket can handle requests for multiple channels.

```elixir
channel "rooms:*", HelloPhoenix.RoomChannel, via: [Phoenix.Transports.WebSocket]
channel "foods:*", HelloPhoenix.FoodChannel
```

We can mount multiple socket handlers in our endpoint:

```elixir
socket "/socket", HelloPhoenix.UserSocket
socket "/admin-socket", HelloPhoenix.AdminSocket
```


### Summary

Routing is a big topic, and we have covered a lot of ground here. The important points to take away from this guide are:
- Routes which begin with an HTTP verb name expand to a single clause of the match function.
- Routes which begin with 'resources' expand to 8 clauses of the match function.
- Resources may restrict the number of match function clauses by using the `only:` or `except:` options.
- Any of these routes may be nested.
- Any of these routes may be scoped to a given path.
- Using the `as:` option in a scope can reduce duplication.
- Using the helper option for scoped routes eliminates unreachable paths.
