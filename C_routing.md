###Routing

Phoenix routing has a dual nature. As we have seen in the preceding guide, it is a way to parse incoming HTTP requests and dispatch to the correct controller and action - passing along any parameters that may have been included. It is also a mechanism for generating a path or url given a previously defined route - passing in any parameters which may be needed.

The router file that Phoenix generates, `web/router.ex`, will look something like this one. Phoenix release 0.5.0 and earlier will, however, have an extra `as: :pages` option on the end of the route (just after `:index` ).

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
The name you gave your application will appear instead of 'HelloPhoenix' for both the router module name and the Controller name.

The first line of this module `use Phoenix.Router` simply makes Phoenix router functions available in our particular router.

Scopes have their own section in this guide, so we won't spend time on the `scope "/" do` block here. The `pipe_through :browser` line will get a full treatment in the Pipeline section of this guide. We'll skip over it for now as well.

Inside the scope block, however, we have our first actual route.
`get "/", HelloPhoenix.Controller, :index`

'get' is a Phoenix macro which expands out to define one clause of the match function. It corresponds to the HTTP verb GET. Similar macros exist for other HTTP verbs including POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE and HEAD.

The first argument to these macros is the path. Here, it is the root of the application, "/". The next two arguments are the controller and action we want to have handle this request. These macros may also take other options, which we will see throughout the rest of this guide.

If this were the only route in our router module, the whole module would look like this after the macro expands.

```elixir
defmodule HelloPhoenix.Router do
  def match(conn, "GET", ["/"]) do
    Controller.perform_action(conn, HelloPhoenix.PageController, :index)
  end
end
```

Clearly, the body of the match function is where the index function of the PageController is called.

As we add more routes, more clauses of the match function will be added to our router module. These will behave like any other multi-clause function in Elixir. They will be tried in order from the top, and the first clause to match the paramates given (verb and path) will be executed. After a match is found, the search will stop and no other clauses will by tried.

This means that it is possible to create a route which will never match, based on the HTTP verb and the path, regardless of the controller and action.

If we do create an ambiguous route, the router will still compile, but we will get a warning. Let's see this in action.

Define this route at the bottom of the `scope "/" do` block in the router.

```elixir
get "/", HelloPhoenix.RootController, :index
```

Then run `$ mix compile` at the root of your project. You will see the following warning from the compiler.

```text
web/router.ex:1: warning: this clause cannot match because a previous clause at line 1 always matches
Compiled web/router.ex
```

###Examining Routes

Phoenix provides a great tool for investigating routes in an application, the mix task `phoenix.routes`.

Let's see how this works. Go to the root of a newly-generated Phoenix application and run `$ mix phoenix.routes`. (If you haven't already done so, you'll need to run `$ mix do deps.get, compile` before running the routes task.) You should see something like the following, generated from the only route we currently have.

```console
$ mix phoenix.routes
page_path  GET  /  HelloPhoenix.PageController.index/2
```

The output tells us that any HTTP GET request for the root of the application will be handled by the index action of the HelloPhoenix.PageController.

`page_path` is an instance of a what Phoenix calls a path helper, and we'll talk about those next.

###Path Helpers

Path helpers are functions which are defined on the `Router.Helpers` module for an individual application. For us, that is `HelloPhoenix.Router.Helpers`, and `page_path` is the function which will return the path to the root of our application.

That's a mouthful. Let's see it in action. Run `$ iex -S mix` at the root of the project. When we call the `page_path` function on our router helpers with the action as an argument, it returns the path to us.

```elixir
iex(4)> HelloPhoenix.Router.Helpers.page_path(:index)
"/"
```

This is significant because we can use the `page_path` function in a template to link to the root of our application.
```html
<a href="<%= HelloPhoenix.Router.Helpers.page_path(:index) %>">To the Welcome Page!</a>
```

###Resources

The router supports other macros besides those for HTTP verbs like `get`, `post` and `put`. The most important among them is `resources`, which expands out to eight clauses of the match function.

Put this line into your router.ex file inside the `scope "/" do` block: `resources "users", HelloPhoenix.UserController`.

Then go to the root of your project, and run `$ mix phoenix.routes`

You should see something like the following. Of course, the name of your project will replace "HelloPhoenix".

```elixir
user_path  GET     /users           HelloPhoenix.UserController.index/2
user_path  GET     /users/:id/edit  HelloPhoenix.UserController.edit/2
user_path  GET     /users/new       HelloPhoenix.UserController.new/2
user_path  GET     /users/:id       HelloPhoenix.UserController.show/2
user_path  POST    /users           HelloPhoenix.UserController.create/2
user_path  PUT     /users/:id       HelloPhoenix.UserController.update/2
user_path  PATCH   /users/:id       HelloPhoenix.UserController.update/2
user_path  DELETE  /users/:id       HelloPhoenix.UserController.destroy/2
```

This is the standard matrix of HTTP verbs, paths and controller actions. Let's look at them individually, in a slightly different order.

- A GET request to /users will invoke the index action to show all the users.
- A GET request to /users/:id will invoke the show action with an id to show an individual user identified by that id.
- A GET request to /users/new will invoke the new action to present a form for creating a new user.
- A POST request to /users will invoke the create action to save a new user to the data store.
- A GET request to /users/:id/edit will invoke the edit action with an id to retrieve an individual user from the data store and present the information in a form for editing.
- A PUT request to /users/:id will invoke the update action with an id to save the updated user to the data store.
- A PATCH request to /users/:id will also invoke the update action with an id to save the updated use to the data store.
- A DELETE request to /users/:id will invoke the destroy action with an id to remove the individual user from the data store.

If we don't feel that we need all of these routes, we can be selective using the `:only` and `:except` options.

Let's say we have a read-only posts resource. We could define it like this.

```elixir
resources "posts", HelloPhoenix.PostController, only: [:index, :show]
```

Running `$ mix phoenix.routes` shows that we now only have the routes to the index and show actions defined.

```elixir
post_path  GET     /posts                         HelloPhoenix.PostsController.index/2
post_path  GET     /posts/:id                     HelloPhoenix.PostsController.show/2
```

Similarly, if we have a comments resource, and we don't want to provide a route to delete one, we could define a route like this.

```elixir
resources "comments", HelloPhoenix.CommentController, except: [:destroy]
```

Running `$ mix phoenix.routes` now shows that we have all the routes except the DELETE request to the destroy action.

```elixir
comment_path  GET     /comments                      HelloPhoenix.CommentController.index/2
comment_path  GET     /comments/:id/edit             HelloPhoenix.CommentController.edit/2
comment_path  GET     /comments/new                  HelloPhoenix.CommentController.new/2
comment_path  GET     /comments/:id                  HelloPhoenix.CommentController.show/2
comment_path  POST    /comments                      HelloPhoenix.CommentController.create/2
comment_path  PUT     /comments/:id                  HelloPhoenix.CommentController.update/2
comment_path  PATCH   /comments/:id                  HelloPhoenix.CommentController.update/2
```

###More on Path Helpers
The phoenix.routes task also listed the user_path as the path function for each line of output. Here is what that path translates to for each action.

```elixir
iex(2)> HelloPhoenix.Router.Helpers.user_path(:index)
"/users"

iex(3)> HelloPhoenix.Router.Helpers.user_path(:show, 17)
"/users/17"

iex(4)> HelloPhoenix.Router.Helpers.user_path(:new)
"/users/new"

iex(5)> HelloPhoenix.Router.Helpers.user_path(:create)
"/users"

iex(6)> HelloPhoenix.Router.Helpers.user_path(:edit, 37)
"/users/37/edit"

iex(7)> HelloPhoenix.Router.Helpers.user_path(:update, 37)
"/users/37"

iex(8)> HelloPhoenix.Router.Helpers.user_path(:destroy, 17)
"/users/17"
```

What about paths with query strings? Phoenix has you covered. By adding an optional third argument of key value pairs, the path helpers will return those pairs in the query string.

```elixir
iex(3)> HelloPhoenix.Router.Helpers.user_path(:show, 17, admin: true, active: false)
"/users/17?admin=true&active=false"
```

What if you need a full url instead of a path? Again, Phoenix has an answer - the Router.Helpers.url function.

```elixir
iex(3)> HelloPhoenix.Router.Helpers.user_path(:index, 42) |> HelloPhoenix.Router.Helpers.url
"http://localhost:4000/users/42"
```

The `Router.Helpers.url` function will get the host, port, proxy port and ssl information needed to construct the full url from the configuration parameters set for each environment. We'll talk about configuration in more detail in it's own guide. For now, you can take a look at `/config/dev.exs` file in your own project to see what those values are.


###Nested Resources

It is also possible to nest resources in a Phoenix router. Let's say we also have a posts resource which has a one to many relationship with users. That is to say, a user can create many posts, and an individual post belongs to only one user. We can represent that with a nested route like this.

```elixir
resources "users", HelloPhoenix.UserControler do
  resources "posts", HelloPhoenix.PostController
end
```
When we run `$ mix phoenix.routes` now, in addition to the routes we saw for users above, we get the following set of routes.

```elixir
user_post_path  GET     users/:user_id/posts           HelloPhoenix.PostController.index/2
user_post_path  GET     users/:user_id/posts/:id/edit  HelloPhoenix.PostController.edit/2
user_post_path  GET     users/:user_id/posts/new       HelloPhoenix.PostController.new/2
user_post_path  GET     users/:user_id/posts/:id       HelloPhoenix.PostController.show/2
user_post_path  POST    users/:user_id/posts           HelloPhoenix.PostController.create/2
user_post_path  PUT     users/:user_id/posts/:id       HelloPhoenix.PostController.update/2
user_post_path  PATCH   users/:user_id/posts/:id       HelloPhoenix.PostController.update/2
user_post_path  DELETE  users/:user_id/posts/:id       HelloPhoenix.PostController.destroy/2
```

We see that each of these routes scopes the posts to a user id. For the first one, we will invoke the `PostController` `index` action, but we will pass in a user_id. This implies that we would display all the posts for that individual user only. The same scoping applies for all these routes.

When calling path helper functions for nested routes, we will need to pass the ids in the order they came in the route definition. For the following show route, 42 is the user_id, and 17 is the post_id.

```elixir
iex(2)> HelloPhoenix.Router.Helpers.user_post_path(:show, 42, 17)
"/users/42/posts/17"
```

Again, if we add a key value pair to the end of the function call, it is added to the query string.

```elixir
iex> HelloPhoenix.Router.Helpers.user_post_path(:index, 42, active: true)
"/users/42/posts?active=true"
```

###Scoped Routes

Scopes are a way to group routes under a common path prefix. We might want to do this for admin functionality, APIs  and especially for versioned APIs. Let's say we have user generated reviews on a site, and that those reviews need to be approved by an admin. The semantics of these resources are quite different, and they may not share the same controller, so we want to keep them separate.

The paths to the user facing reviews would look like a standard resource.

```text
/reviews
/reviews/1234
/reviews/1234/edit

and so on
```

The admin review paths could be prefixed with "/admin".

```text
/admin/reviews
/admin/reviews/1234
/admin/reviews/1234/edit

and so on
```

We accomplish this with a scoped route that sets a path option to "/admin" like this one.

```elixir
scope "/admin" do
  pipe_through :browser

  resources "/reviews", HelloPhoenix.Admin.ReviewController
end
```

Note that Phoenix will assume that the path we set ought to begin with a slash, so `scope "/admin" do` and `scope "admin" do` will both produce the same results.

```elixir
review_path  GET     /admin/reviews           HelloPhoenix.Admin.ReviewController.index/2
review_path  GET     /admin/reviews/:id/edit  HelloPhoenix.Admin.ReviewController.edit/2
review_path  GET     /admin/reviews/new       HelloPhoenix.Admin.ReviewController.new/2
review_path  GET     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.show/2
review_path  POST    /admin/reviews           HelloPhoenix.Admin.ReviewController.create/2
review_path  PUT     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
             PATCH   /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
review_path  DELETE  /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.destroy/2
```

This looks good, but there is a problem here. Remember that we wanted both user facing reviews routes as well as the admin ones. When we define both of those routes in our router, like this,

```elixir
resources "/reviews", ReviewController

scope "/admin" do
  resources "/reviews", Admin.ReviewController
end
```

and we run `$ mix phoenix.routes`, we get this output.

```elixir
review_path  GET     /reviews                 HelloPhoenix.ReviewController.index/2
review_path  GET     /reviews/:id/edit        HelloPhoenix.ReviewController.edit/2
review_path  GET     /reviews/new             HelloPhoenix.ReviewController.new/2
review_path  GET     /reviews/:id             HelloPhoenix.ReviewController.show/2
review_path  POST    /reviews                 HelloPhoenix.ReviewController.create/2
review_path  PUT     /reviews/:id             HelloPhoenix.ReviewController.update/2
             PATCH   /reviews/:id             HelloPhoenix.ReviewController.update/2
review_path  DELETE  /reviews/:id             HelloPhoenix.ReviewController.destroy/2
review_path  GET     /admin/reviews           HelloPhoenix.Admin.ReviewController.index/2
review_path  GET     /admin/reviews/:id/edit  HelloPhoenix.Admin.ReviewController.edit/2
review_path  GET     /admin/reviews/new       HelloPhoenix.Admin.ReviewController.new/2
review_path  GET     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.show/2
review_path  POST    /admin/reviews           HelloPhoenix.Admin.ReviewController.create/2
review_path  PUT     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
             PATCH   /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
review_path  DELETE  /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.destroy/2
```

The actual routes we get all look right, except for the path helper at the beginning of each line. We are getting the same helper for both the user facing review routes and the admin ones. We can fix this problem by adding a `as: :admin` option to our admin scope.

```elixir
resources "/reviews", ReviewController

scope "/admin", as: :admin do
  resources "/reviews", Admin.ReviewController
end
```

`$ mix phoenix.routes` now shows us we have what we are looking for.

```elixir
      review_path  GET     /reviews                 HelloPhoenix.ReviewController.index/2
      review_path  GET     /reviews/:id/edit        HelloPhoenix.ReviewController.edit/2
      review_path  GET     /reviews/new             HelloPhoenix.ReviewController.new/2
      review_path  GET     /reviews/:id             HelloPhoenix.ReviewController.show/2
      review_path  POST    /reviews                 HelloPhoenix.ReviewController.create/2
      review_path  PUT     /reviews/:id             HelloPhoenix.ReviewController.update/2
                   PATCH   /reviews/:id             HelloPhoenix.ReviewController.update/2
      review_path  DELETE  /reviews/:id             HelloPhoenix.ReviewController.destroy/2
admin_review_path  GET     /admin/reviews           HelloPhoenix.Admin.ReviewController.index/2
admin_review_path  GET     /admin/reviews/:id/edit  HelloPhoenix.Admin.ReviewController.edit/2
admin_review_path  GET     /admin/reviews/new       HelloPhoenix.Admin.ReviewController.new/2
admin_review_path  GET     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.show/2
admin_review_path  POST    /admin/reviews           HelloPhoenix.Admin.ReviewController.create/2
admin_review_path  PUT     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
                   PATCH   /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
admin_review_path  DELETE  /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.destroy/2
```

The path helpers return what we want them to as well. Run `$ iex -S mix` and give them a try.

```elixir
iex(1)> HelloPhoenix.Router.Helpers.review_path(:index)
"/reviews"

iex(2)> HelloPhoenix.Router.Helpers.admin_review_path(:show, 1234)
"/admin/reviews/1234"
```

What if we had a number of resources that were all handled by admins? We could put all of them inside the same scope.

```elixir
scope "/admin", as: :admin do
  resources "/images", HelloPhoenix.Admin.ImageController
  resources "/reviews", HelloPhoenix.Admin.ReviewController
  resources "/users", HelloPhoenix.Admin.UserController
end
```

Here's what `$ mix phoenix.routes` tells us.

```elixir
 admin_image_path  GET     /admin/images            HelloPhoenix.Admin.ImageController.index/2
 admin_image_path  GET     /admin/images/:id/edit   HelloPhoenix.Admin.ImageController.edit/2
 admin_image_path  GET     /admin/images/new        HelloPhoenix.Admin.ImageController.new/2
 admin_image_path  GET     /admin/images/:id        HelloPhoenix.Admin.ImageController.show/2
 admin_image_path  POST    /admin/images            HelloPhoenix.Admin.ImageController.create/2
 admin_image_path  PUT     /admin/images/:id        HelloPhoenix.Admin.ImageController.update/2
                   PATCH   /admin/images/:id        HelloPhoenix.Admin.ImageController.update/2
 admin_image_path  DELETE  /admin/images/:id        HelloPhoenix.Admin.ImageController.destroy/2
admin_review_path  GET     /admin/reviews           HelloPhoenix.Admin.ReviewController.index/2
admin_review_path  GET     /admin/reviews/:id/edit  HelloPhoenix.Admin.ReviewController.edit/2
admin_review_path  GET     /admin/reviews/new       HelloPhoenix.Admin.ReviewController.new/2
admin_review_path  GET     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.show/2
admin_review_path  POST    /admin/reviews           HelloPhoenix.Admin.ReviewController.create/2
admin_review_path  PUT     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
                   PATCH   /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
admin_review_path  DELETE  /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.destroy/2
  admin_user_path  GET     /admin/users             HelloPhoenix.Admin.UserController.index/2
  admin_user_path  GET     /admin/users/:id/edit    HelloPhoenix.Admin.UserController.edit/2
  admin_user_path  GET     /admin/users/new         HelloPhoenix.Admin.UserController.new/2
  admin_user_path  GET     /admin/users/:id         HelloPhoenix.Admin.UserController.show/2
  admin_user_path  POST    /admin/users             HelloPhoenix.Admin.UserController.create/2
  admin_user_path  PUT     /admin/users/:id         HelloPhoenix.Admin.UserController.update/2
                   PATCH   /admin/users/:id         HelloPhoenix.Admin.UserController.update/2
  admin_user_path  DELETE  /admin/users/:id         HelloPhoenix.Admin.UserController.destroy/2
```

This is great, exactly what we want, but we can make it even better. Notice that for each resource, we needed to fully qualify the controller name with "HelloPhoenix.Admin"? That's tedious and error prone. Assuming the name of each of our controllers actually begins with "HelloPhoenix.Admin", we can add an `alias: HelloPhoenix.Admin` option to our scope declaration, and all of our routes will have the correct, fully qualified controller name.

```elixir
scope "/admin", as: :admin, alias: HelloPhoenix.Admin do
  resources "/images", ImageController
  resources "/reviews", ReviewController
  resources "/users", UserController
end
```

`$ mix phoenix.routes` tells us that we get the same result as when we qualified each controller name individually.

```elixir
 admin_image_path  GET     /admin/images            HelloPhoenix.Admin.ImageController.index/2
 admin_image_path  GET     /admin/images/:id/edit   HelloPhoenix.Admin.ImageController.edit/2
 admin_image_path  GET     /admin/images/new        HelloPhoenix.Admin.ImageController.new/2
 admin_image_path  GET     /admin/images/:id        HelloPhoenix.Admin.ImageController.show/2
 admin_image_path  POST    /admin/images            HelloPhoenix.Admin.ImageController.create/2
 admin_image_path  PUT     /admin/images/:id        HelloPhoenix.Admin.ImageController.update/2
                   PATCH   /admin/images/:id        HelloPhoenix.Admin.ImageController.update/2
 admin_image_path  DELETE  /admin/images/:id        HelloPhoenix.Admin.ImageController.destroy/2
admin_review_path  GET     /admin/reviews           HelloPhoenix.Admin.ReviewController.index/2
admin_review_path  GET     /admin/reviews/:id/edit  HelloPhoenix.Admin.ReviewController.edit/2
admin_review_path  GET     /admin/reviews/new       HelloPhoenix.Admin.ReviewController.new/2
admin_review_path  GET     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.show/2
admin_review_path  POST    /admin/reviews           HelloPhoenix.Admin.ReviewController.create/2
admin_review_path  PUT     /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
                   PATCH   /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.update/2
admin_review_path  DELETE  /admin/reviews/:id       HelloPhoenix.Admin.ReviewController.destroy/2
  admin_user_path  GET     /admin/users             HelloPhoenix.Admin.UserController.index/2
  admin_user_path  GET     /admin/users/:id/edit    HelloPhoenix.Admin.UserController.edit/2
  admin_user_path  GET     /admin/users/new         HelloPhoenix.Admin.UserController.new/2
  admin_user_path  GET     /admin/users/:id         HelloPhoenix.Admin.UserController.show/2
  admin_user_path  POST    /admin/users             HelloPhoenix.Admin.UserController.create/2
  admin_user_path  PUT     /admin/users/:id         HelloPhoenix.Admin.UserController.update/2
                   PATCH   /admin/users/:id         HelloPhoenix.Admin.UserController.update/2
  admin_user_path  DELETE  /admin/users/:id         HelloPhoenix.Admin.UserController.destroy/2
```

As a bonus, we could nest all of the routes for our application inside a scope that simply has an alias for the name of our Phoenix app, and eliminate the duplication in our controller names.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  scope "/", alias: HelloPhoenix do
    pipe_through :browser

    get "/images", ImageController, :index
    resources "/reviews", ReviewController
    resources "/users", UserController
  end
end
```

`$ mix phoenix.routes` tells us that all of our controllers now have the correct, fully-qualified names.

```elixir
image_path   GET     /images            HelloPhoenix.ImageController.index/2
review_path  GET     /reviews           HelloPhoenix.ReviewController.index/2
review_path  GET     /reviews/:id/edit  HelloPhoenix.ReviewController.edit/2
review_path  GET     /reviews/new       HelloPhoenix.ReviewController.new/2
review_path  GET     /reviews/:id       HelloPhoenix.ReviewController.show/2
review_path  POST    /reviews           HelloPhoenix.ReviewController.create/2
review_path  PUT     /reviews/:id       HelloPhoenix.ReviewController.update/2
             PATCH   /reviews/:id       HelloPhoenix.ReviewController.update/2
review_path  DELETE  /reviews/:id       HelloPhoenix.ReviewController.destroy/2
  user_path  GET     /users             HelloPhoenix.UserController.index/2
  user_path  GET     /users/:id/edit    HelloPhoenix.UserController.edit/2
  user_path  GET     /users/new         HelloPhoenix.UserController.new/2
  user_path  GET     /users/:id         HelloPhoenix.UserController.show/2
  user_path  POST    /users             HelloPhoenix.UserController.create/2
  user_path  PUT     /users/:id         HelloPhoenix.UserController.update/2
             PATCH   /users/:id         HelloPhoenix.UserController.update/2
  user_path  DELETE  /users/:id         HelloPhoenix.UserController.destroy/2
```

Note: The `:as` and `:alias` options may appear in any order, and the resulting routes will be the same.

Scopes can also nest, just as resources can. If we had a versioned api with resources for images, reviews and users, we could define routes for them like this.

```elixir
scope "/api", alias: HelloPhoenix.Api, as: :api do
  scope "/v1", alias: V1, as: :v1 do
    resources "/images", ImageController
    resources "/reviews", ReviewController
    resources "/users", UserController\
  end
end
```

`$ mix phoenix.routes` tells us that have the routes we're looking for.

```elixir
 api_v1_image_path  GET     /api/v1/images            HelloPhoenix.Api.V1.ImageController.index/2
 api_v1_image_path  GET     /api/v1/images/:id/edit   HelloPhoenix.Api.V1.ImageController.edit/2
 api_v1_image_path  GET     /api/v1/images/new        HelloPhoenix.Api.V1.ImageController.new/2
 api_v1_image_path  GET     /api/v1/images/:id        HelloPhoenix.Api.V1.ImageController.show/2
 api_v1_image_path  POST    /api/v1/images            HelloPhoenix.Api.V1.ImageController.create/2
 api_v1_image_path  PUT     /api/v1/images/:id        HelloPhoenix.Api.V1.ImageController.update/2
                    PATCH   /api/v1/images/:id        HelloPhoenix.Api.V1.ImageController.update/2
 api_v1_image_path  DELETE  /api/v1/images/:id        HelloPhoenix.Api.V1.ImageController.destroy/2
api_v1_review_path  GET     /api/v1/reviews           HelloPhoenix.Api.V1.ReviewController.index/2
api_v1_review_path  GET     /api/v1/reviews/:id/edit  HelloPhoenix.Api.V1.ReviewController.edit/2
api_v1_review_path  GET     /api/v1/reviews/new       HelloPhoenix.Api.V1.ReviewController.new/2
api_v1_review_path  GET     /api/v1/reviews/:id       HelloPhoenix.Api.V1.ReviewController.show/2
api_v1_review_path  POST    /api/v1/reviews           HelloPhoenix.Api.V1.ReviewController.create/2
api_v1_review_path  PUT     /api/v1/reviews/:id       HelloPhoenix.Api.V1.ReviewController.update/2
                    PATCH   /api/v1/reviews/:id       HelloPhoenix.Api.V1.ReviewController.update/2
api_v1_review_path  DELETE  /api/v1/reviews/:id       HelloPhoenix.Api.V1.ReviewController.destroy/2
  api_v1_user_path  GET     /api/v1/users             HelloPhoenix.Api.V1.UserController.index/2
  api_v1_user_path  GET     /api/v1/users/:id/edit    HelloPhoenix.Api.V1.UserController.edit/2
  api_v1_user_path  GET     /api/v1/users/new         HelloPhoenix.Api.V1.UserController.new/2
  api_v1_user_path  GET     /api/v1/users/:id         HelloPhoenix.Api.V1.UserController.show/2
  api_v1_user_path  POST    /api/v1/users             HelloPhoenix.Api.V1.UserController.create/2
  api_v1_user_path  PUT     /api/v1/users/:id         HelloPhoenix.Api.V1.UserController.update/2
                    PATCH   /api/v1/users/:id         HelloPhoenix.Api.V1.UserController.update/2
  api_v1_user_path  DELETE  /api/v1/users/:id         HelloPhoenix.Api.V1.UserController.destroy/2
```

###Channel Routes

Channels are a very exciting, realtime component of the Phoenix framework. They are so important that they will have a guide of their own.

Channels are roughly analogous to controllers except that they are capable of bi-directional communication and their connections persist beyond the initial response. They are also closely tied to a client - written for JavaScript, iOS or Android. For now, we'll focus on defining routes for them and leave a detailed discussion of their capabilities to the Channel Guide.

Each channel depend on a socket mounted at a given point for it's communication. The first thing we need to do to define a route for a channel, then, is to define a socket and specify the path to it's mount point.

Here's what that looks like in our router file.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/my_socket"
end
```

The next thing we need to do is define a channel, giving it a name and associating it with a channel module which will implement it's behavior. If we have a channel module called "OurChannel" and a channel called "our_channel_name", the code to do this is straightforward, `channel "our_channel_name", HelloPhoenix.OurChannel`

The whole router, then, looks like this.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router
  use Phoenix.Router.Socket, mount: "/my_socket"

  channel "our_channel_name", HelloPhoenix.OurChannel
end
```


###Summary

Routing is a big topic, and we have covered a lot of ground here. The important points to take away from this guide are:
- Routes which begin with an HTTP verb name expand to a single clause of the match function.
- Routes which begin with 'resources' expand to 8 clauses of the match function.
- Resources may restrict the number of match function clauses by using the "only:" or "except:" options.
- Any of these routes may be nested.
- Any of these routes may be scoped to a given path.
- Using the alias option in a scope can reduce the duplication in controller names.
- Using the helper option for scoped routes eliminates unreachable paths.
- Scoped routes may also be nested.
