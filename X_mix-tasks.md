There are currently three built-in Phoenix-specific mix tasks available to us within a newly-generated application.

```console
$ mix help | grep -i phoenix
mix phoenix.new       # Creates Phoenix application
mix phoenix.routes    # Prints all routes
mix phoenix.server    # Starts applications and their servers
```
We have seen all of these at one point or another in the guides, but having all the information about them in one place seems like a good idea. And here we are.

#### `mix phoenix.new`

This is how we tell Phoenix the framework to generate a new Phoenix application for us. We saw it early on in the [Up and Running Guide](http://www.phoenixframework.org/v0.8.0/docs/up-and-running)

We need to pass this task a name for our application, and a path so Phoenix knows where to create it. Conventionally, we use all lower-case letters with underscores for the name (snake case). We can use either a relative or absolute path for the second argument. The only requirement is that the path must be outside of Phoenix itself.

This relative path works.

```console
$ mix phoenix.new task_tester ../task_tester
* creating ../task_tester/.gitignore
* creating ../task_tester/README.md
* creating ../task_tester/config/config.exs
* creating ../task_tester/config/dev.exs
* creating ../task_tester/config/locales/en.exs
* creating ../task_tester/config/prod.exs
* creating ../task_tester/config/test.exs
* creating ../task_tester/lib/task_tester.ex
* creating ../task_tester/lib/task_tester/endpoint.ex
* creating ../task_tester/mix.exs
* creating ../task_tester/test/task_tester_test.exs
* creating ../task_tester/test/test_helper.exs
* creating ../task_tester/web/channels/.gitkeep
* creating ../task_tester/web/controllers/page_controller.ex
* creating ../task_tester/web/models/.gitkeep
* creating ../task_tester/web/router.ex
* creating ../task_tester/web/templates/layout/application.html.eex
* creating ../task_tester/web/templates/page/error.html.eex
* creating ../task_tester/web/templates/page/index.html.eex
* creating ../task_tester/web/templates/page/not_found.html.eex
* creating ../task_tester/web/view.ex
* creating ../task_tester/web/views/error_view.ex
* creating ../task_tester/web/views/layout_view.ex
* creating ../task_tester/web/views/page_view.ex
* creating ../task_tester/priv/static/css/phoenix.css
* creating ../task_tester/priv/static/images/phoenix.png
* creating ../task_tester/priv/static/js/phoenix.js
```
This absolute path works as well.

```console
$ mix phoenix.new task_tester /Users/lance/work/task_tester
* creating /Users/lance/work/task_tester/.gitignore
* creating /Users/lance/work/task_tester/README.md
* creating /Users/lance/work/task_tester/config/config.exs
* creating /Users/lance/work/task_tester/config/dev.exs
* creating /Users/lance/work/task_tester/config/locales/en.exs
* creating /Users/lance/work/task_tester/config/prod.exs
* creating /Users/lance/work/task_tester/config/test.exs
* creating /Users/lance/work/task_tester/lib/task_tester.ex
* creating /Users/lance/work/task_tester/lib/task_tester/endpoint.ex
* creating /Users/lance/work/task_tester/mix.exs
* creating /Users/lance/work/task_tester/test/task_tester_test.exs
* creating /Users/lance/work/task_tester/test/test_helper.exs
* creating /Users/lance/work/task_tester/web/channels/.gitkeep
* creating /Users/lance/work/task_tester/web/controllers/page_controller.ex
* creating /Users/lance/work/task_tester/web/models/.gitkeep
* creating /Users/lance/work/task_tester/web/router.ex
* creating /Users/lance/work/task_tester/web/templates/layout/application.html.eex
* creating /Users/lance/work/task_tester/web/templates/page/error.html.eex
* creating /Users/lance/work/task_tester/web/templates/page/index.html.eex
* creating /Users/lance/work/task_tester/web/templates/page/not_found.html.eex
* creating /Users/lance/work/task_tester/web/view.ex
* creating /Users/lance/work/task_tester/web/views/error_view.ex
* creating /Users/lance/work/task_tester/web/views/layout_view.ex
* creating /Users/lance/work/task_tester/web/views/page_view.ex
* creating /Users/lance/work/task_tester/priv/static/css/phoenix.css
* creating /Users/lance/work/task_tester/priv/static/images/phoenix.png
* creating /Users/lance/work/task_tester/priv/static/js/phoenix.js
```

#### `mix phoenix.routes`

This task has a single purpose, to show us all the routes defined for a given router. We saw it used extensively in the [Routing Guide](http://www.phoenixframework.org/v0.8.0/docs/routing).

If we don't specify a router for this task, it will default to the router Phoenix generated for us.

```console
$ mix phoenix.routes
page_path  GET  /  TaskTester.PageController.index/2
```
We can also specify an individual router if we have more than one for our application.

```console
$ mix phoenix.routes TaskTester.Router
page_path  GET  /  TaskTester.PageController.index/2
```

#### `mix phoenix.server`

This is the task we use to get our application running. It takes no arguments at all. If we pass any in, they will be silently ignored.

```console
$ mix phoenix.server
16:09:43.435 [debug] Running TaskTester.Endpoint with Cowboy on port 4000 (http)
```
It silently ignores our `DoesNotExist` argument.

```console
$ mix phoenix.server DoesNotExist
16:10:17.018 [debug] Running TaskTester.Endpoint with Cowboy on port 4000 (http)
```
Prior to the 0.8.x versions of Phoenix, we used the `phoenix.start` task to get our applications running. That task no longer exists, and attempting to run it will cause an error.

```console
$ mix phoenix.start
** (Mix) The task phoenix.start could not be found
```
If we would like to start our application and also have an `iex` session open to it, we can run the mix task within `iex` like this, `iex -S mix phoenix.server`.

```console
$ iex -S mix phoenix.server
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Running TaskTester.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```
