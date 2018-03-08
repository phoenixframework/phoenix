# Mix Tasks

There are currently a number of built-in Phoenix-specific and ecto-specific mix tasks available to us within a newly-generated application. We can also create our own application specific tasks.

## Phoenix Specific Mix Tasks

```console

➜ mix help | grep -i phx
mix local.phx          # Updates the Phoenix project generator locally
mix phx.digest         # Digests and compresses static files
mix phx.digest.clean   # Removes old versions of static assets.
mix phx.gen.channel    # Generates a Phoenix channel
mix phx.gen.context    # Generates a context with functions around an Ecto schema
mix phx.gen.embedded   # Generates an embedded Ecto schema file
mix phx.gen.html       # Generates controller, views, and context for an HTML resource
mix phx.gen.json       # Generates controller, views, and context for a JSON resource
mix phx.gen.presence   # Generates a Presence tracker
mix phx.gen.schema     # Generates an Ecto schema and migration file
mix phx.gen.secret     # Generates a secret
mix phx.new            # Creates a new Phoenix v1.3.0 application
mix phx.new.ecto       # Creates a new Ecto project within an umbrella project
mix phx.new.web        # Creates a new Phoenix web project within an umbrella project
mix phx.routes         # Prints all routes
mix phx.server         # Starts applications and their servers
```

We have seen all of these at one point or another in the guides, but having all the information about them in one place seems like a good idea. And here we are.

#### `mix phx.new`

This is how we tell Phoenix the framework to generate a new Phoenix application for us. We saw it early on in the [Up and Running Guide](up_and_running.html).

Before we begin, we should note that Phoenix uses [Ecto](https://github.com/elixir-lang/ecto) for database access and [Brunch.io](http://brunch.io/) for asset management by default. We can pass `--no-ecto` to opt out of Ecto and  `--no-brunch` to opt out of Brunch.io.

> Note: If we do use Brunch.io, we need to install its dependencies before we start our application. `phx.new` will ask to do this for us. Otherwise, we can install them with `npm install`. If we don't install them, the app will throw errors and may not serve our assets properly.

We need to pass `phx.new` a name for our application. Conventionally, we use all lower-case letters with underscores.

```console
$ mix phx.new task_tester
* creating task_tester/.gitignore
. . .
```

We can also use either a relative or absolute path.

This relative path works.

```console
$ mix phx.new ../task_tester
* creating ../task_tester/.gitignore
. . .
```

This absolute path works as well.

```console
$ mix phx.new /Users/me/work/task_tester
* creating /Users/me/work/task_tester/.gitignore
. . .
```

The `phx.new` task will also ask us if we want to install our dependencies. (Please see the note above about Brunch.io dependencies.)

```console
Fetch and install dependencies? [Yn] y
* running npm install && node node_modules/brunch/bin/brunch build
* running mix deps.get
```

Once all of our dependencies are installed, `phx.new` will tell us what our next steps are.

```console
We are all set! Run your Phoenix application:

$ cd task_tester
$ mix phx.server

You can also run it inside IEx (Interactive Elixir) as:

$ iex -S mix phx.server
```

By default `phx.new` will assume we want to use ecto for our contexts. If we don't want to use ecto in our application, we can use the `--no-ecto` flag.

```console
$ mix phx.new task_tester --no-ecto
* creating task_tester/.gitignore
. . .
```

With the `--no-ecto` flag, Phoenix will not make either ecto or postgrex a dependency of our application, and it will not create a `repo.ex` file.

By default, Phoenix will name our OTP application after the name we pass into `phx.new`. If we want, we can specify a different OTP application name with the `--app` flag.

```console
$  mix phx.new task_tester --app hello
* creating task_tester/config/config.exs
* creating task_tester/config/dev.exs
* creating task_tester/config/prod.exs
* creating task_tester/config/prod.secret.exs
* creating task_tester/config/test.exs
* creating task_tester/lib/hello/application.ex
* creating task_tester/lib/hello.ex
* creating task_tester/lib/hello_web/channels/user_socket.ex
* creating task_tester/lib/hello_web/views/error_helpers.ex
* creating task_tester/lib/hello_web/views/error_view.ex
* creating task_tester/lib/hello_web/endpoint.ex
* creating task_tester/lib/hello_web/router.ex
* creating task_tester/lib/hello_web.ex
* creating task_tester/mix.exs
. . .
```

If we look in the resulting `mix.exs` file, we will see that our project app name is `hello`.

```elixir
defmodule Hello.Mixfile do
  use Mix.Project

  def project do
    [app: :hello,
     version: "0.1.0",
. . .
```

A quick check will show that all of our module names are qualified with `Hello`.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller
. . .
```

We can also see that files related to the application as a whole - eg. files in `lib/` and the test seed file - have `hello` in their names.

```console
* creating task_tester/lib/hello.ex
* creating task_tester/lib/hello/endpoint.ex
* creating task_tester/lib/hello/repo.ex
* creating task_tester/test/hello_test.exs
```

If we only want to change the qualifying prefix for module names, we can do that with the `--module` flag. It's important to note that the value of the `--module` must look like a valid module name with proper capitalization. The task will throw an error if it doesn't.

```console
$  mix phx.new task_tester --module Hello
* creating task_tester/config/config.exs
* creating task_tester/config/dev.exs
* creating task_tester/config/prod.exs
* creating task_tester/config/prod.secret.exs
* creating task_tester/config/test.exs
* creating task_tester/lib/task_tester.ex
* creating task_tester/lib/task_tester/endpoint.ex
* creating task_tester/priv/static/robots.txt
* creating task_tester/test/controllers/page_controller_test.exs
* creating task_tester/test/views/error_view_test.exs
* creating task_tester/test/views/page_view_test.exs
* creating task_tester/test/support/conn_case.ex
* creating task_tester/test/support/channel_case.ex
* creating task_tester/test/test_helper.exs
* creating task_tester/web/controllers/page_controller.ex
* creating task_tester/web/templates/layout/app.html.eex
* creating task_tester/web/templates/page/index.html.eex
* creating task_tester/web/views/error_view.ex
* creating task_tester/web/views/layout_view.ex
* creating task_tester/web/views/page_view.ex
* creating task_tester/web/router.ex
* creating task_tester/web/web.ex
* creating task_tester/mix.exs
* creating task_tester/README.md
* creating task_tester/lib/task_tester/repo.ex
. . .
```

Notice that none of the files have `hello` in their names. All filenames related to the application name are `task_tester`.

If we look at the project app name in `mix.exs`, we see that it is `task_tester`, but all the module qualifying names begin with `Hello`.

```elixir
defmodule Hello.Mixfile do
  use Mix.Project

  def project do
    [app: :task_tester,
. . .
```

#### `mix phx.gen.html`

Phoenix now offers the ability to generate all the code to stand up a complete HTML resource - ecto migration, ecto context, controller with all the necessary actions, view, and templates. This can be a tremendous timesaver. Let's take a look at how to make this happen.

The `phx.gen.html` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/templates/post/edit.html.eex
* creating lib/hello_web/templates/post/form.html.eex
* creating lib/hello_web/templates/post/index.html.eex
* creating lib/hello_web/templates/post/new.html.eex
* creating lib/hello_web/templates/post/show.html.eex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello/blog/post.ex
* creating priv/repo/migrations/20170906150129_create_posts.exs
* creating lib/hello/blog/blog.ex
* injecting lib/hello/blog/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

When `phx.gen.html` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/posts", PostController

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 17 files (.ex)

== Compilation error in file lib/hello_web/controllers/post_controller.ex ==
** (CompileError) lib/hello_web/controllers/post_controller.ex:22: undefined function post_path/3
    (stdlib) lists.erl:1338: :lists.foreach/2
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (elixir) lib/kernel/parallel_compiler.ex:121: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
```

If we don't want to create a context or schema for our resource we can use the `--no-context` flag. Note that this still requires a context module name as a parameter.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer --no-context
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/templates/post/edit.html.eex
* creating lib/hello_web/templates/post/form.html.eex
* creating lib/hello_web/templates/post/index.html.eex
* creating lib/hello_web/templates/post/new.html.eex
* creating lib/hello_web/templates/post/show.html.eex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
```

It will tell us we need to add a line to our router file, but since we skipped the context, it won't mention anything about `ecto.migrate`.

```console
Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/posts", PostController
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 15 files (.ex)

== Compilation error in file lib/hello_web/views/post_view.ex ==
** (CompileError) lib/hello_web/templates/post/edit.html.eex:3: undefined function post_path/3
    (stdlib) lists.erl:1338: :lists.foreach/2
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (elixir) lib/kernel/parallel_compiler.ex:121: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
```

Similarly - if we want a context created without a schema for our resource we can use the `--no-schema` flag.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer --no-schema
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/templates/post/edit.html.eex
* creating lib/hello_web/templates/post/form.html.eex
* creating lib/hello_web/templates/post/index.html.eex
* creating lib/hello_web/templates/post/new.html.eex
* creating lib/hello_web/templates/post/show.html.eex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello/blog/blog.ex
* injecting lib/hello/blog/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

It will tell us we need to add a line to our router file, but since we skipped the schema, it won't mention anything about `ecto.migrate`.

```console
Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/posts", PostController
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 15 files (.ex)

== Compilation error in file lib/hello_web/views/post_view.ex ==
** (CompileError) lib/hello_web/templates/post/edit.html.eex:3: undefined function post_path/3
    (stdlib) lists.erl:1338: :lists.foreach/2
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (elixir) lib/kernel/parallel_compiler.ex:121: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
```

#### `mix phx.gen.json`

Phoenix also offers the ability to generate all the code to stand up a complete JSON resource - ecto migration, ecto schema, controller with all the necessary actions and view. This command will not create any template for the app.

The `phx.gen.json` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

```console
$ mix phx.gen.json Blog Post posts title:string content:string
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello_web/views/changeset_view.ex
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/blog/post.ex
* creating priv/repo/migrations/20170906153323_create_posts.exs
* creating lib/hello/blog/blog.ex
* injecting lib/hello/blog/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

When `phx.gen.json` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to your :api scope in lib/hello_web/router.ex:

    resources "/posts", PostController, except: [:new, :edit]


Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 19 files (.ex)

== Compilation error in file lib/hello_web/controllers/post_controller.ex ==
** (CompileError) lib/hello_web/controllers/post_controller.ex:18: undefined function post_path/3
    (stdlib) lists.erl:1338: :lists.foreach/2
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (elixir) lib/kernel/parallel_compiler.ex:121: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
```

If we don't want to create a context or schema for our resource we can use the `--no-context` flag. Note that this still requires a context module name as a parameter.

```console
$ mix phx.gen.json Blog Post posts title:string content:string --no-context
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello_web/views/changeset_view.ex
* creating lib/hello_web/controllers/fallback_controller.ex
```

It will tell us we need to add a line to our router file, but since we skipped the context, it won't mention anything about `ecto.migrate`.

```console
Add the resource to your :api scope in lib/hello_web/router.ex:

    resources "/posts", PostController, except: [:new, :edit]
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 17 files (.ex)

== Compilation error in file lib/hello_web/controllers/post_controller.ex ==
** (CompileError) lib/hello_web/controllers/post_controller.ex:15: Hello.Blog.Post.__struct__/0 is undefined, cannot expand struct Hello.Blog.Post
    (stdlib) lists.erl:1354: :lists.mapfoldl/3
    (stdlib) lists.erl:1355: :lists.mapfoldl/3
    (stdlib) lists.erl:1354: :lists.mapfoldl/3
    lib/hello_web/controllers/post_controller.ex:14: (module)
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
```

Similarly - if we want a context created without a schema for our resource we can use the `--no-schema` flag.

```console
$ mix phx.gen.json Blog Post posts title:string content:string --no-schema
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello_web/views/changeset_view.ex
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/blog/blog.ex
* injecting lib/hello/blog/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

It will tell us we need to add a line to our router file, but since we skipped the context, it won't mention anything about `ecto.migrate`.

```console
Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/posts", PostController
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phx.server
Compiling 18 files (.ex)

== Compilation error in file lib/hello/blog/blog.ex ==
** (CompileError) lib/hello/blog/blog.ex:65: Hello.Blog.Post.__struct__/0 is undefined, cannot expand struct Hello.Blog.Post
    lib/hello/blog/blog.ex:65: (module)
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (elixir) lib/kernel/parallel_compiler.ex:121: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
```

#### `mix phx.gen.context`

If we don't need a complete HTML/JSON resource and instead are only interested in a context, we can use the `phx.gen.context` task. It will generate a context, a schema, a migration and a test case.

The `phx.gen.context` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes.

```console
$ mix phx.gen.context Accounts User users name:string age:integer
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170906161158_create_users.exs
* creating lib/hello/accounts/accounts.ex
* injecting lib/hello/accounts/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs
```

> Note: If we need to namespace our resource we can simply namespace the first argument of the generator.

```console
* creating lib/hello/admin/accounts/user.ex
* creating priv/repo/migrations/20170906161246_create_users.exs
* creating lib/hello/admin/accounts/accounts.ex
* injecting lib/hello/admin/accounts/accounts.ex
* creating test/hello/admin/accounts/accounts_test.exs
* injecting test/hello/admin/accounts/accounts_test.exs
```

#### `mix phx.gen.schema`

If we don't need a complete HTML/JSON resource and are not interested in generating or altering a context we can use the `phx.gen.schema` task. It will generate a schema, and a migration.

The `phx.gen.schema` task takes a number of arguments, the module name of the schema (which may be namespaced), the resource name, and a list of column_name:type attributes.

```console
$ mix phx.gen.schema Accounts.Credential credentials email:string:unique user_id:references:users
* creating lib/hello/accounts/credential.ex
* creating priv/repo/migrations/20170906162013_create_credentials.exs
```

#### `mix phx.gen.channel`

This task will generate a basic Phoenix channel as well a test case for it. It takes the module name for the channel as argument:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs
```

When `phx.gen.channel` is done, it helpfully tells us that we need to add a channel route to our router file.

```console
Add the channel to your `lib/hello_web/channels/user_socket.ex` handler, for example:

    channel "rooms:lobby", HelloWeb.RoomChannel
```

#### `mix phx.gen.presence`

This task will generate a Presence tracker. The module name can be passed as an argument,
`Presence` is used if no module name is passed.

```console
$ mix phx.gen.presence Presence
$ lib/hello_web/channels/presence.ex
```

#### `mix phx.routes`

This task has a single purpose, to show us all the routes defined for a given router. We saw it used extensively in the [Routing Guide](routing.html).

If we don't specify a router for this task, it will default to the router Phoenix generated for us.

```console
$ mix phx.routes
page_path  GET  /  TaskTester.PageController.index/2
```
We can also specify an individual router if we have more than one for our application.

```console
$ mix phx.routes TaskTesterWeb.Router
page_path  GET  /  TaskTesterWeb.PageController.index/2
```

#### `mix phx.server`

This is the task we use to get our application running. It takes no arguments at all. If we pass any in, they will be silently ignored.

```console
$ mix phx.server
[info] Running TaskTesterWeb.Endpoint with Cowboy on port 4000 (http)
```
It silently ignores our `DoesNotExist` argument.

```console
$ mix phx.server DoesNotExist
[info] Running TaskTesterWeb.Endpoint with Cowboy on port 4000 (http)
```
If we would like to start our application and also have an `iex` session open to it, we can run the mix task within `iex` like this, `iex -S mix phx.server`.

```console
$ iex -S mix phx.server
Erlang/OTP 17 [erts-6.4] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

[info] Running TaskTesterWeb.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.4) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

#### `mix phx.digest`

This task does two things, it creates a digest for our static assets and then compresses them.

"Digest" here refers to an MD5 digest of the contents of an asset which gets added to the filename of that asset. This creates a sort of "fingerprint" for it. If the digest doesn't change, browsers and CDNs will use a cached version. If it does change, they will re-fetch the new version.

Before we run this task let's inspect the contents of two directories in our hello application.

First `priv/static` which should look similar to this:

```console
├── images
│   └── phoenix.png
├── robots.txt
```

And then `assets/` which should look similar to this:

```console
├── css
│   └── app.css
├── js
│   └── app.js
├── vendor
│   └── phoenix.js
```

All of these files are our static assets. Now let's run the `mix phx.digest` task.

```console
$ mix phx.digest
Check your digested files at 'priv/static'.
```

We can now do as the task suggests and inspect the contents of `priv/static` directory. We'll see that all files from `assets/` have been copied over to `priv/static` and also each file now has a couple of versions. Those versions are:

* the original file
* a compressed file with gzip
* a file containing the original file name and its digest
* a compressed file containing the file name and its digest

We can optionally determine which files should be gzipped by using the `:gzippable_exts` option in the config file:

```elixir
config :phoenix, :gzippable_exts, ~w(.js .css)
```

> Note: We can specify a different output folder where `phx.digest` will put processed files. The first argument is the path where the static files are located.
```console
$ mix phx.digest priv/static -o www/public
Check your digested files at 'www/public'.
```

## Ecto Specific Mix Tasks

Newly generated Phoenix applications now include ecto and postgrex as dependencies by default (which is to say, unless we use the `--no-ecto` flag with `phx.new`). With those dependencies come mix tasks to take care of common ecto operations. Let's see which tasks we get out of the box.

```console
$ mix help | grep -i ecto
mix ecto.create          # Create the storage for the repo
mix ecto.drop            # Drop the storage for the repo
mix ecto.gen.migration   # Generate a new migration for the repo
mix ecto.gen.repo        # Generates a new repository
mix ecto.migrate         # Runs migrations up on a repo
mix ecto.rollback        # Reverts migrations down on a repo
```

Note: We can run any of the tasks above with the `--no-start` flag to execute the task without starting the application.

#### `ecto.create`
This task will create the database specified in our repo. By default it will look for the repo named after our application (the one generated with our app unless we opted out of ecto), but we can pass in another repo if we want.

Here's what it looks like in action.

```console
$ mix ecto.create
The database for Hello.Repo has been created.
```

If we happen to have another repo called `OurCustom.Repo` that we want to create the database for, we can run this.

```console
$ mix ecto.create -r OurCustom.Repo
The database for OurCustom.Repo has been created.
```

There are a few things that can go wrong with `ecto.create`. If our Postgres database doesn't have a "postgres" role (user), we'll get an error like this one.

```console
$ mix ecto.create
** (Mix) The database for Hello.Repo couldn't be created, reason given: psql: FATAL:  role "postgres" does not exist
```

We can fix this by creating the "postgres" role in the `psql` console with the permissions needed to log in and create a database.

```console
=# CREATE ROLE postgres LOGIN CREATEDB;
CREATE ROLE
```

If the "postgres" role does not have permission to log in to the application, we'll get this error.

```console
$ mix ecto.create
** (Mix) The database for Hello.Repo couldn't be created, reason given: psql: FATAL:  role "postgres" is not permitted to log in
```

To fix this, we need to change the permissions on our "postgres" user to allow login.

```console
=# ALTER ROLE postgres LOGIN;
ALTER ROLE
```

If the "postgres" role does not have permission to create a database, we'll get this error.

```console
$ mix ecto.create
** (Mix) The database for Hello.Repo couldn't be created, reason given: ERROR:  permission denied to create database
```

To fix this, we need to change the permissions on our "postgres" user in the `psql` console  to allow database creation.

```console
=# ALTER ROLE postgres CREATEDB;
ALTER ROLE
```

If the "postgres" role is using a password different from the default "postgres", we'll get this error.

```console
$ mix ecto.create
** (Mix) The database for Hello.Repo couldn't be created, reason given: psql: FATAL:  password authentication failed for user "postgres"
```

To fix this, we can change the password in the environment specific configuration file. For the development environment the password used can be found at the bottom of the `config/dev.exs` file.

#### `ecto.drop`

This task will drop the database specified in our repo. By default it will look for the repo named after our application (the one generated with our app unless we opted out of ecto). It will not prompt us to check if we're sure we want to drop the db, so do exercise caution.

```console
$ mix ecto.drop
The database for Hello.Repo has been dropped.
```

If we happen to have another repo that we want to drop the database for, we can specify it with the `-r` flag.

```console
$ mix ecto.drop -r OurCustom.Repo
The database for OurCustom.Repo has been dropped.
```

#### `ecto.gen.repo`

Many applications require more than one data store. For each data store, we'll need a new repo, and we can generate them automatically with `ecto.gen.repo`.

If we name our repo `OurCustom.Repo`, this task will create it here `lib/our_custom/repo.ex`.

```console
$ mix ecto.gen.repo -r OurCustom.Repo
* creating lib/our_custom
* creating lib/our_custom/repo.ex
* updating config/config.exs
Don't forget to add your new repo to your supervision tree
(typically in lib/hello.ex):

worker(OurCustom.Repo, [])
```

Notice that this task has updated `config/config.exs`. If we take a look, we'll see this extra configuration block for our new repo.

```elixir
. . .
config :hello, OurCustom.Repo,
adapter: Ecto.Adapters.Postgres,
database: "hello_repo",
username: "user",
password: "pass",
hostname: "localhost"
. . .
```

Of course, we'll need to change the login credentials to match what our database expects. We'll also need to change the config for other environments.

We certainly should follow the instructions and add our new repo to our supervision tree. In our `Hello` application, we would open up `lib/hello.ex`, and add our repo as a worker to the `children` list.

```elixir
. . .
children = [
  # Start the endpoint when the application starts
  supervisor(HelloWeb.Endpoint, []),
  # Start the Ecto repository
  worker(Hello.Repo, []),
  # Here you could define other workers and supervisors as children
  # worker(Hello.Worker, [arg1, arg2, arg3]),
  worker(OurCustom.Repo, []),
]
. . .
```

#### `ecto.gen.migration`

Migrations are a programmatic, repeatable way to affect changes to a database schema. Migrations are also just modules, and we can create them with the `ecto.gen.migration` task. Let's walk through the steps to create a migration for a new comments table.

We simply need to invoke the task with a snake_case version of the module name that we want. Preferably, the name will describe what we want the migration to do.

```console
mix ecto.gen.migration add_comments_table
* creating priv/repo/migrations
* creating priv/repo/migrations/20150318001628_add_comments_table.exs
```

Notice that the migration's filename begins with a string representation of the date and time the file was created.

Let's take a look at the file `ecto.gen.migration` has generated for us at `priv/repo/migrations/20150318001628_add_comments_table.exs`.

```elixir
defmodule Hello.Repo.Migrations.AddCommentsTable do
  use Ecto.Migration

  def change do
  end
end
```

Notice that there is a single function `change/0` which will handle both forward migrations and rollbacks. We'll define the schema changes that we want using ecto's handy dsl, and ecto will figure out what to do depending on whether we are rolling forward or rolling back. Very nice indeed.

What we want to do is create a `comments` table with a `body` column, a `word_count` column, and timestamp columns for `inserted_at` and `updated_at`.

```elixir
. . .
def change do
  create table(:comments) do
    add :body,       :string
    add :word_count, :integer
    timestamps
  end
end
. . .
```

Again, we can run this task with the `-r` flag and another repo if we need to.

```console
$ mix ecto.gen.migration -r OurCustom.Repo add_users
* creating priv/repo/migrations
* creating priv/repo/migrations/20150318172927_add_users.exs
```
For more information on how to modify your database schema please refer to the
ecto's migration dsl [ecto migration docs](https://hexdocs.pm/ecto/Ecto.Migration.html).
For example, to alter an existing schema see the documentation on ecto’s
[`alter/2`](https://hexdocs.pm/ecto/Ecto.Migration.html#alter/2) function.

That's it! We're ready to run our migration.

#### `ecto.migrate`

Once we have our migration module ready, we can simply run `mix ecto.migrate` to have our changes applied to the database.

```console
$ mix ecto.migrate
[info] == Running Hello.Repo.Migrations.AddCommentsTable.change/0 forward
[info] create table comments
[info] == Migrated in 0.1s
```

When we first run `ecto.migrate`, it will create a table for us called `schema_migrations`. This will keep track of all the migrations which we run by storing the timestamp portion of the migration's filename.

Here's what the `schema_migrations` table looks like.

```console
hello_dev=# select * from schema_migrations;
version     |     inserted_at
----------------+---------------------
20150317170448 | 2015-03-17 21:07:26
20150318001628 | 2015-03-18 01:45:00
(2 rows)
```

When we roll back a migration, `ecto.rollback` will remove the record representing this migration from `schema_migrations`.

By default, `ecto.migrate` will execute all pending migrations. We can exercise more control over which migrations we run by specifying some options when we run the task.

We can specify the number of pending migrations we would like to run with the `-n` or `--step` options.

```console
$ mix ecto.migrate -n 2
[info] == Running Hello.Repo.Migrations.CreatePost.change/0 forward
[info] create table posts
[info] == Migrated in 0.0s
[info] == Running Hello.Repo.Migrations.AddCommentsTable.change/0 forward
[info] create table comments
[info] == Migrated in 0.0s
```

The `--step` option will behave the same way.

```console
mix ecto.migrate --step 2
```

We can also specify an individual migration we would like to run with the `-v` option.

```console
mix ecto.migrate -v 20150317170448
```

The `--to` option will behave the same way.

```console
mix ecto.migrate --to 20150317170448
```

#### `ecto.rollback`

The `ecto.rollback` task will reverse the last migration we have run, undoing the schema changes. `ecto.migrate` and `ecto.rollback` are mirror images of each other.

```console
$ mix ecto.rollback
[info] == Running Hello.Repo.Migrations.AddCommentsTable.change/0 backward
[info] drop table comments
[info] == Migrated in 0.0s
```

`ecto.rollback` will handle the same options as `ecto.migrate`, so `-n`, `--step`, `-v`, and `--to` will behave as they do for `ecto.migrate`.

## Creating Our Own Mix Tasks

As we've seen throughout this guide, both mix itself and the dependencies we bring in to our application provide a number of really useful tasks for free. Since neither of these could possibly anticipate all our individual application's needs, mix allows us to create our own custom tasks. That's exactly what we are going to do now.

The first thing we need to do is create a `mix/tasks` directory inside of `lib`. This is where any of our application specific mix tasks will go.

```console
$ mkdir -p lib/mix/tasks
```

Inside that directory, let's create a new file, `hello.greeting.ex`, that looks like this.

```elixir
defmodule Mix.Tasks.Hello.Greeting do
  use Mix.Task

  @shortdoc "Sends a greeting to us from Hello Phoenix"

  @moduledoc """
    This is where we would put any long form documentation or doctests.
  """

  def run(_args) do
    Mix.shell.info "Greetings from the Hello Phoenix Application!"
  end

  # We can define other functions as needed here.
end
```

Let's take a quick look at the moving parts involved in a working mix task.

The first thing we need to do is name our module. In order to properly namespace it, we begin with `Mix.Tasks`. We'd like to invoke this as `mix hello.greeting`, so we complete the module name with
`Hello.Greeting`.

The `use Mix.Task` line clearly brings in functionality from mix that makes this module behave as a mix task.

The `@shortdoc` module attribute holds a string which will describe our task when users invoke `mix help`.

`@moduledoc` serves the same function that it does in any module. It's where we can put long-form documentation and doctests, if we have any.

The `run/1` function is the critical heart of any mix task. It's the function that does all the work when users invoke our task. In ours, all we do is send a greeting from our app, but we can implement our `run/1` function to do whatever we need it to. Note that `Mix.shell.info/1` is the preferred way to print text back out to the user.

Of course, our task is just a module, so we can define other private functions as needed to support our `run/1` function.

Now that we have our task module defined, our next step is to compile the application.

```console
$ mix compile
Compiled lib/tasks/hello.greeting.ex
Generated hello.app
```

Now our new task should be visible to `mix help`.

```console
$ mix help | grep hello
mix hello.greeting # Sends a greeting to us from Hello Phoenix
```

Notice that `mix help` displays the text we put into the `@shortdoc` along with the name of our task.

So far, so good, but does it work?

```console
$ mix hello.greeting
Greetings from the Hello Phoenix Application!
```

Indeed it does.

If you want to make your new mix task to use your application's infrastructure, you need to make sure the application is started when mix task is being executed. This is particularly useful if you need to access your database from within the mix task. Thankfully, mix makes it really easy for us:

```elixir
  . . .
  def run(_args) do
    Mix.Task.run "app.start"
    Mix.shell.info "Now I have access to Repo and other goodies!"
  end
  . . .
```
