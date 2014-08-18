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

As we add more routes, more clauses of the match function will be added to our router module. These will behave like any other multi-clause function in Elixir. They will be tried in order from the top, and the first clause to match will be executed. After a mach is found, the search will stop and no other clauses will by tried.

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

Phoenix provides a great tool for investigating routes in your application, the mix task `$ mix phoenix.routes`.

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

The "as: :page" portion of the route has been translated into "page_path" in the output. In effect, we have named a resource for this route; we've called it "page". "page_path" is the name of a function which will expand out to the path that will lead back to this route from within the application.

That's a mouthful. All it really means is that we can use the "page_path" function to link to the root of our application.
```html
<a href="<%= Router.page_path %>">To the Welcome Page!</a>
```

If you try to give the same name to another route, the router will not compile. Try adding the following route to the bottom of your router and run `$ mix compile`.

`get "/page", HelloPhoenix.AnotherController, :index, as: :page`

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

###Path Helpers


###Resources
  - the seven basic routes/actions
  - nested resources

###Scopes


###Sockets
  - channels
  - topics
