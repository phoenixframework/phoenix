###Routing

Phoenix routing has a dual nature. As we have seen in the preceding guide, it is a way to parse incoming HTTP requests and dispatch to the correct controller and action - passing along any parameters that may have been included. It is also a mechanism for generating a path or url given a previously defined named route - passing in any parameters which may be needed.

The router file that Phoenix generates for you, web/router.ex, will look something like this one.

```elixir
defmodule HelloPhoenix.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :test
  get "/", HelloPhoenix.PageController, :index, as: :page
end
```
Whatever you called your application will appear instead of 'HelloPhoenix' for both the router module name and the PageController name.

The first line of this module `use Phoenix.Router` simply makes Phoenix router functions available in our particular router.

The next line `plug Plug.Static, at: "/static", from: :hello_phoenix` tells the middleware layer, plug, where to serve our static assets from. JavaScript, image, and CSS files each have their own directory under /static.

Now we come to our first application level route.
`get "/", HelloPhoenix.PageController, :index, as: :page`

'get' is a Phoenix macro which expands out to define one clause of the match function. It corresponds to the HTTP verb GET. Similar macros exist for other HTTP verbs including POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE and HEAD.

The first argument to these macros is the path. Here, it is the root of the application, "/". The next two arguments are the controller and action we want to have handle this request. Finally, "as: :page" is a way of naming this route, which we will talk about in a moment.

If this were the only route in our router module, the whole module would look like this after invoking the macro.

```elixir
defmodule HelloPhoenix.Router do
  def match(conn, "GET", ["/"]) do
    Controller.perform_action(conn, PageController, :index)
  end
end
```

The body of this function is where the index function of the PageController is called.

As we add more routes, more clauses of the match function will be added to our router module. These will behave like any other multi-clause function in Elixir. They will be tried in order from the top, and the first clause to match will be executed. After a match is found, the search will stop and no other clauses will by tried.

This means that it is possible to create a route which will never be called, based on the HTTP verb and the path, regardless of the controller and action.

If you do create an ambiguous route, the router will still compile, but you will get a warning. Let's see this in action.

Define this route at the very bottom of your router.

```
get "/", HelloPhoenix.RootController, :index
```

Then run `$ mix compile` at the root of your project. You will see the following warning from the compiler.

```
web/router.ex:1: warning: this clause cannot match because a previous clause at line 1 always matches
Compiled web/router.ex
```

###Examining Routes

Phoenix provides a great tool for investigating routes in your application, the mix task phoenix.routes.

Let's see how this works. Go to the root of a newly-generated Phoenix application and run `$ mix phoenix.routes`. (If you haven't already done so, you'll need to run `$ mix do deps.get, compile` before running the routes task.) You should see something like this.

```
$ mix phoenix.routes
page_path  GET  /  Elixir.HelloPhoenix.PageController.index/2
```

The line in the router which generates that output is this, which we have examined above.

```elixir
get "/", HelloPhoenix.PageController, :index, as: :page
```

The output tells us that any HTTP GET request for the root of the application will be handled by the index action of the HelloPhoenix.PageController.

The "as: :page" portion of the route has been translated into "page_path" in the output. The "page_path" function is a path helper, and we'll talk about those next.

###Path Helpers

By adding "as: :page", we have in effect named a resource for this route; we've called it "page". "page_path" is the name of a function which will expand out to the path that will lead back to this route from within the application.

That's a mouthful. Let's see it in action. Run `$ iex -S mix` at the root of the project. When we call the pages_path function on our router with the action as an argument, it returns the path to us.

```
iex(4)> HelloPhoenix.Router.pages_path(:index)
"/"
```

This is significant because we can use the "page_path" function to link to the root of our application.
```html
<a href="<%= HelloPhoenix.Router.page_path %>">To the Welcome Page!</a>
```

If you try to give the same name to another route, the router will not compile. Try adding the following route to the bottom of your router. `get "/page", HelloPhoenix.AnotherController, :index, as: :page`

Then run `$ mix compile`

```
== Compilation error on file web/router.ex ==
** (CompileError) web/router.ex:1: def page_path/1 has default values and multiple clauses, define a function head with the defaults
    (elixir) src/elixir_def.erl:340: :elixir_def.store_each/8
    (elixir) src/elixir_def.erl:107: :elixir_def.store_definition/9
    (stdlib) erl_eval.erl:657: :erl_eval.do_apply/6
    (stdlib) erl_eval.erl:121: :erl_eval.exprs/5
    (elixir) src/elixir.erl:170: :elixir.erl_eval/3
    /Users/lance/work/hello_phoenix/web/router.ex:1: Phoenix.Router.Mapper.__before_compile__/1
    (elixir) src/elixir.erl:170: :elixir.erl_eval/3
    (elixir) src/elixir.erl:158: :elixir.eval_forms/4
```

###Resources

The router supports other macros besides those for HTTP verbs like 'get', 'post' and 'put'. The most important among them is 'resources', which expands out to eight clauses of the match function.

Put this line into your router.ex file `resources "users", HelloPhoenix.UsersController`

Then go to the root of your project, and run ``$ mix phoenix.routes`

You should see something like the following. Of course, the name of your project will replace "HelloPhoenix".

```elixir
users_path  GET     /users           Elixir.HelloPhoenix.UsersController.index/2
users_path  GET     /users/:id/edit  Elixir.HelloPhoenix.UsersController.edit/2
users_path  GET     /users/new       Elixir.HelloPhoenix.UsersController.new/2
users_path  GET     /users/:id       Elixir.HelloPhoenix.UsersController.show/2
users_path  POST    /users           Elixir.HelloPhoenix.UsersController.create/2
users_path  PUT     /users/:id       Elixir.HelloPhoenix.UsersController.update/2
users_path  PATCH   /users/:id       Elixir.HelloPhoenix.UsersController.update/2
users_path  DELETE  /users/:id       Elixir.HelloPhoenix.UsersController.destroy/2
```

This is the standard matrix of HTTP verbs, paths and controller actions. Let's look at them individually, in a slightly different order.

- A GET request to /users will invoke the index action to show all the users.
- A GET request to /users/:id will invoke the show action with an id to show an individual user.
- A GET request to /users/new will invoke the new action to present a form for creating a new user.
- A POST request to /users will invoke the create action to save a new user to the data store.
- A GET request to /users/:id/edit will invoke the edit action with an id to retrieve an individual user from the data store and present the information in a form for editing.
- A PUT request to /users/:id will invoke the update action with an id to save the updated user to the data store.
- A PATCH request to /users/:id will also invoke the update action with an id to save the updated use to the data store.
- A DELETE request to /users/:id will invoke the destroy action with an id to remove the individual user from the data store.

If we don't feel that we need all of these routes, we can be selective using the :only and :except options.

Let's say we have a read-only posts resource. We could define it like this.

```elixir
resources "posts", HelloPhoenix.PostsController, only: [:index, :show]
```

Running `$ mix phoenix.routes` shows that we now only have the routes to the index and show actions defined.

```elixir
      posts_path  GET     /posts                         Elixir.HelloPhoenix.PostsController.index/2
      posts_path  GET     /posts/:id                     Elixir.HelloPhoenix.PostsController.show/2
```

Similarly, if we have a comments resource that we don't want to ever remove, we could define a route like this.

```elixir
resources "comments", HelloPhoenix.CommentsController, except: [:destroy]
```

Running `$ mix phoenix.routes` now shows that we have all the routes except the DELETE request to the destroy action.

```elixir
   comments_path  GET     /comments                      Elixir.HelloPhoenix.CommentsController.index/2
   comments_path  GET     /comments/:id/edit             Elixir.HelloPhoenix.CommentsController.edit/2
   comments_path  GET     /comments/new                  Elixir.HelloPhoenix.CommentsController.new/2
   comments_path  GET     /comments/:id                  Elixir.HelloPhoenix.CommentsController.show/2
   comments_path  POST    /comments                      Elixir.HelloPhoenix.CommentsController.create/2
   comments_path  PUT     /comments/:id                  Elixir.HelloPhoenix.CommentsController.update/2
   comments_path  PATCH   /comments/:id                  Elixir.HelloPhoenix.CommentsController.update/2
```

###Path Helpers
The phoenix.routes task also listed the users_path as the path function for each line of output. Here is what that path translates to for each action.

```
iex(2)> HelloPhoenix.Router.users_path(:index)
"/users"

iex(3)> HelloPhoenix.Router.users_path(:show, 17)
"/users/17"

iex(4)> HelloPhoenix.Router.users_path(:new)
"/users/new"

iex(5)> HelloPhoenix.Router.users_path(:create)
"/users"

iex(6)> HelloPhoenix.Router.users_path(:edit, 37)
"/users/37/edit"

iex(7)> HelloPhoenix.Router.users_path(:update, 37)
"/users/37"

iex(8)> HelloPhoenix.Router.users_path(:destroy, 17)
"/users/17"
```

What about paths with query strings? Phoenix has you covered. By adding an optional third argument of key value pairs, the path helpers will return those pairs in the query string.

```elixir
iex(3)> HelloPhoenix.Router.users_path(:show, 17, admin: true, active: false)
"/users/17?admin=true&active=false"
```

What if you need a full url instead of a path? Again, Phoenix has an answer in the Router.url function.

```elixir
iex(3)> HelloPhoenix.Router.users_path(:index, 42) |> HelloPhoenix.Router.url
"http://localhost:4000/users/42"
```

The Router.url function will get the host, port, proxy port and ssl information needed to construct the full url from the configuration parameters set for each environment. We'll talk about configuration in more detail in it's own guide. For now, you can take a look at /config/dev.exs in your own project to see what those values are.


###Nested Resources

It is also possible to nest resources. Let's say we also have a posts resourse which has a one to many relationship with users. That is to say, a user can create many posts, and any post belongs to only one user. We can represent that with a nested route like this.

```elixir
resources "users", HelloPhoenix.UsersControler do
  resources "posts", HelloPhoenix.PostsController
end
```

When we run `$ mix phoenix.routes` now, in addition to the routes we saw for users above, we get the following set of routes.

```elixir
users_posts_path  GET     users/:user_id/posts           Elixir.HelloPhoenix.PostsController.index/2
users_posts_path  GET     users/:user_id/posts/:id/edit  Elixir.HelloPhoenix.PostsController.edit/2
users_posts_path  GET     users/:user_id/posts/new       Elixir.HelloPhoenix.PostsController.new/2
users_posts_path  GET     users/:user_id/posts/:id       Elixir.HelloPhoenix.PostsController.show/2
users_posts_path  POST    users/:user_id/posts           Elixir.HelloPhoenix.PostsController.create/2
users_posts_path  PUT     users/:user_id/posts/:id       Elixir.HelloPhoenix.PostsController.update/2
users_posts_path  PATCH   users/:user_id/posts/:id       Elixir.HelloPhoenix.PostsController.update/2
users_posts_path  DELETE  users/:user_id/posts/:id       Elixir.HelloPhoenix.PostsController.destroy/2
```

We see that each of these routes scopes the posts to a user id. For the first one, we will invoke the PostsController index action, but we will pass in a user_id. This implies that we would display all the posts for that individual user. The same scoping applies for all these routes.

Path helpers for nested routes will need to have the ids listed in the order they came in the route definition. For this show route, 42 is the user_id, and 17 is the id for the post.

```elixir
iex(2)> HelloPhoenix.Router.users_posts_path(:show, 42, 17)
"/users/42/posts/17"
```

Again, if we add a key value pair to the end of the function call, it is added to the query string.

```elixir
iex> HelloPhoenix.Router.users_posts_path(:index, 42, active: true)
"/users/42/posts?active=true"
```

###Scoped Routes


###Channel Routes
