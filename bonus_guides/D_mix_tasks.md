There are currently a number of built-in Phoenix-specific and ecto-specific mix tasks available to us within a newly-generated application. We can also create our own application specific tasks.

## Phoenix Specific Mix Tasks

```console
$ mix help | grep -i phoenix
mix phoenix.digest      # Digests and compress static files
mix phoenix.gen.channel # Generates a Phoenix channel
mix phoenix.gen.html    # Generates controller, model and views for an HTML-based resource
mix phoenix.gen.json    # Generates a controller and model for an JSON-based resource
mix phoenix.gen.model   # Generates an Ecto model
mix phoenix.new         # Create a new Phoenix v0.13.1 application
mix phoenix.routes      # Prints all routes
mix phoenix.server      # Starts applications and their servers
```
We have seen all of these at one point or another in the guides, but having all the information about them in one place seems like a good idea. And here we are.

#### `mix phoenix.new`

This is how we tell Phoenix the framework to generate a new Phoenix application for us. We saw it early on in the [Up and Running Guide](http://www.phoenixframework.org/docs/up-and-running).

Before we begin, we should note that Phoenix uses [Ecto](https://github.com/elixir-lang/ecto) for database access and [Brunch.io](http://brunch.io/) for asset management by default. We can pass `--no-ecto` to opt out of Ecto and  `--no-brunch` to opt out of Brunch.io.

> Note: If we do use Brunch.io, we need to install its dependencies before we start our application. `phoenix.new` will ask to do this for us. Otherwise, we can install them with `npm install`. If we don't install them, the app will throw errors and may not serve our assets properly.

We need to pass `phoenix.new` a name for our application. Conventionally, we use all lower-case letters with underscores.

```console
$ mix phoenix.new task_tester
* creating task_tester/.gitignore
. . .
```

We can also use either a relative or absolute path.

This relative path works.

```console
$ mix phoenix.new ../task_tester
* creating ../task_tester/.gitignore
. . .
```

This absolute path works as well.

```console
$ mix phoenix.new /Users/me/work/task_tester
* creating /Users/me/work/task_tester/.gitignore
. . .
```

The `phoenix.new` task will also ask us if we want to install our dependencies. (Please see the note above about Brunch.io dependencies.)

```console
Fetch and install dependencies? [Yn] y
* running npm install
* running mix deps.get
```

Once all of our dependencies are installed, `phoenix.new` will tell us what our next steps are.

```console
We are all set! Run your Phoenix application:

$ cd task_tester
$ mix phoenix.server

You can also run it inside IEx (Interactive Elixir) as:

$ iex -S mix phoenix.server
```

By default `phoenix.new` will assume we want to use ecto for our models. If we don't want to use ecto in our application, we can use the `--no-ecto` flag.

```console
$ mix phoenix.new task_tester --no-ecto
* creating task_tester/.gitignore
. . .
```

With the `--no-ecto` flag, Phoenix will not make either ecto or postgrex a dependency of our application, and it will not create a `repo.ex` file.

By default, Phoenix will name our OTP application after the name we pass into `phoenix.new`. If we want, we can specify a different OTP application name with the `--app` flag.

```console
$  mix phoenix.new task_tester --app hello_phoenix
* creating task_tester/config/config.exs
* creating task_tester/config/dev.exs
* creating task_tester/config/prod.exs
* creating task_tester/config/prod.secret.exs
* creating task_tester/config/test.exs
* creating task_tester/lib/hello_phoenix.ex
* creating task_tester/lib/hello_phoenix/endpoint.ex
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
* creating task_tester/lib/hello_phoenix/repo.ex
. . .
```

If we look in the resulting `mix.exs` file, we will see that our project app name is `hello_phoenix`.

```elixir
defmodule HelloPhoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :hello_phoenix,
    version: "0.0.1",
. . .
```

A quick check will show that all of our module names are qualified with `HelloPhoenix`.

```elixir
defmodule HelloPhoenix.PageController do
  use HelloPhoenix.Web, :controller
. . .
```

We can also see that files related to the application as a whole - eg. files in `lib/` and the test seed file - have `hello_phoenix` in their names.

```console
* creating task_tester/lib/hello_phoenix.ex
* creating task_tester/lib/hello_phoenix/endpoint.ex
* creating task_tester/lib/hello_phoenix/repo.ex
* creating task_tester/test/hello_phoenix_test.exs
```

If we only want to change the qualifying prefix for module names, we can do that with the `--module` flag. It's important to note that the value of the `--module` must look like a valid module name with proper capitalization. The task will throw an error if it doesn't.

```console
$  mix phoenix.new task_tester --module HelloPhoenix
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

Notice that none of the files have `hello_phoenix` in their names. All filenames related to the application name are `task_tester`.

If we look at the project app name in `mix.exs`, we see that it is `task_tester`, but all the module qualifying names begin with `HelloPhoenix`.

```elixir
defmodule HelloPhoenix.Mixfile do
  use Mix.Project

  def project do
    [app: :task_tester,
. . .
```

#### `mix phoenix.gen.html`

Phoenix now offers the ability to generate all the code to stand up a complete HTML resource - ecto migration, ecto model, controller with all the necessary actions, view, and templates. This can be a tremendous timesaver. Let's take a look at how to make this happen.

The `phoenix.gen.html` task takes a number of arguments, the module name of the model, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

```console
$ mix phoenix.gen.html Post posts body:string word_count:integer
* creating priv/repo/migrations/20150523120903_create_post.exs
* creating web/models/post.ex
* creating test/models/post_test.exs
* creating web/controllers/post_controller.ex
* creating web/templates/post/edit.html.eex
* creating web/templates/post/form.html.eex
* creating web/templates/post/index.html.eex
* creating web/templates/post/new.html.eex
* creating web/templates/post/show.html.eex
* creating web/views/post_view.ex
* creating test/controllers/post_controller_test.exs
```

When `phoenix.gen.html` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to the proper scope in web/router.ex:

resources "/posts", PostController

and then update your repository by running migrations:

$ mix ecto.migrate
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phoenix.server
Compiled web/models/post.ex

== Compilation error on file web/controllers/post_controller.ex ==
** (CompileError) web/controllers/post_controller.ex:27: function post_path/2 undefined
(stdlib) lists.erl:1336: :lists.foreach/2
(stdlib) erl_eval.erl:657: :erl_eval.do_apply/6
```

If we don't want to create a model for our resource we can use the `--no-model` flag.

```console
$ mix phoenix.gen.html Post posts body:string word_count:integer --no-model
* creating web/controllers/post_controller.ex
* creating web/templates/post/edit.html.eex
* creating web/templates/post/form.html.eex
* creating web/templates/post/index.html.eex
* creating web/templates/post/new.html.eex
* creating web/templates/post/show.html.eex
* creating web/views/post_view.ex
* creating test/controllers/post_controller_test.exs
```

It will tell us we need to add a line to our router file, but since we skipped the model, it won't mention anything about `ecto.migrate`.

```console
Add the resource to the proper scope in web/router.ex:

resources "/posts", PostController
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phoenix.server

== Compilation error on file web/views/post_view.ex ==
** (CompileError) web/templates/post/edit.html.eex:4: function post_path/3 undefined
    (stdlib) lists.erl:1336: :lists.foreach/2
    (stdlib) erl_eval.erl:657: :erl_eval.do_apply/6
```

#### `mix phoenix.gen.json`

Phoenix also offers the ability to generate all the code to stand up a complete JSON resource - ecto migration, ecto model, controller with all the necessary actions and view. This command will not create any template for the app.

The `phoenix.gen.json` task takes a number of arguments, the module name of the model, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

```console
$ mix phoenix.gen.json Post posts title:string content:string
* creating priv/repo/migrations/20150521140551_create_post.exs
* creating web/models/post.ex
* creating test/models/post_test.exs
* creating web/controllers/post_controller.ex
* creating web/views/post_view.ex
* creating test/controllers/post_controller_test.exs
* creating web/views/changeset_view.ex
```

When `phoenix.gen.json` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to the proper scope in web/router.ex:

    resources "/posts", PostController

and then update your repository by running migrations:

    $ mix ecto.migrate
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phoenix.server
Compiled web/models/post.ex

== Compilation error on file web/controllers/post_controller.ex ==
** (CompileError) web/controllers/post_controller.ex:27: function post_path/2 undefined
(stdlib) lists.erl:1336: :lists.foreach/2
(stdlib) erl_eval.erl:657: :erl_eval.do_apply/6
```

If we don't want to create a model for our resource we can use the `--no-model` flag.

```console
$ mix phoenix.gen.json Post posts title:string content:string --no-model
* creating web/controllers/post_controller.ex
* creating web/views/post_view.ex
* creating test/controllers/post_controller_test.exs
* creating web/views/changeset_view.ex
```

It will tell us we need to add a line to our router file, but since we skipped the model, it won't mention anything about `ecto.migrate`.

```console
Add the resource to the proper scope in web/router.ex:

resources "/posts", PostController
```

Important: If we don't do this, our application won't compile, and we'll get an error.

```console
$ mix phoenix.server

== Compilation error on file web/controllers/post_controller.ex ==
** (CompileError) web/controllers/post_controller.ex:15: HelloPhoenix.Post.__struct__/0 is undefined, cannot expand struct HelloPhoenix.Post
    (elixir) src/elixir_map.erl:55: :elixir_map.translate_struct/4
    (stdlib) lists.erl:1352: :lists.mapfoldl/3
```

#### `mix phoenix.gen.model`

If we don't need a complete HTML/JSON resource and instead are only interested in a model, we can use the `phoenix.gen.model` task. It will generate a model, a migration and a test case.

The `phoenix.gen.model` task takes a number of arguments, the module name of the model, the plural model name used for the schema, and a list of column_name:type attributes.

```console
$ mix phoenix.gen.model User users name:string age:integer
* creating priv/repo/migrations/20150527185323_create_user.exs
* creating web/models/user.ex
* creating test/models/user_test.exs
```

> Note: If we need to namespace our resource we can simply namespace the first argument of the generator.
```console
$ mix phoenix.gen.model Admin.User users name:string age:integer
* creating priv/repo/migrations/20150527185940_create_admin_user.exs
* creating web/models/admin/user.ex
* creating test/models/admin/user_test.exs
```

#### `mix phoenix.gen.channel`

This task will generate a basic Phoenix channel as well a test case for it. It takes only two arguments, the module name for the channel and plural used as the topic.

```console
$ mix phoenix.gen.channel Room rooms
* creating web/channels/room_channel.ex
* creating test/channels/room_channel_test.exs
```

When `phoenix.gen.channel` is done, it helpfully tells us that we need to add a channel route to our router file.

```console
Add the channel to a socket scope in web/router.ex:

socket "/ws", HelloPhoenix do
  channel "rooms:lobby", RoomChannel
end
```

#### `mix phoenix.routes`

This task has a single purpose, to show us all the routes defined for a given router. We saw it used extensively in the [Routing Guide](http://www.phoenixframework.org/docs/routing).

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
[info] Running TaskTester.Endpoint with Cowboy on port 4000 (http)
```
It silently ignores our `DoesNotExist` argument.

```console
$ mix phoenix.server DoesNotExist
[info] Running TaskTester.Endpoint with Cowboy on port 4000 (http)
```
Prior to the 0.8.x versions of Phoenix, we used the `phoenix.start` task to get our applications running. That task no longer exists, and attempting to run it will cause an error.

```console
$ mix phoenix.start
** (Mix) The task phoenix.start could not be found
```
If we would like to start our application and also have an `iex` session open to it, we can run the mix task within `iex` like this, `iex -S mix phoenix.server`.

```console
$ iex -S mix phoenix.server
Erlang/OTP 17 [erts-6.4] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

[info] Running TaskTester.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.4) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

#### `mix phoenix.digest`

This task does two things, it creates a digest for our static assets and then compresses them.

"Digest" here refers to an MD5 digest of the contents of an asset which gets added to the filename of that asset. This creates a sort of "fingerprint" for it. If the digest doesn't change, browsers and CDNs will use a cached version. If it does change, they will re-fetch the new version.

Before we run this task let's inspect the contents of two directories in our hello_phoenix application.

First `priv/static` which should look similar to this:

```text
├── images
│   └── phoenix.png
├── robots.txt
```

And then `web/static/` which should look similar to this:

```text
├── css
│   └── app.scss
├── js
│   └── app.js
├── vendor
│   └── phoenix.js
```

All of these files are our static assets. Now let's run the `mix phoenix.digest` task.

```console
$ mix phoenix.digest
Check your digested files at 'priv/static'.
```

We can now do as the task suggests and inspect the contents of `priv/static` directory. We'll see that all files from `web/static/` have been copied over to `priv/static` and also each file now has a couple of versions. Those versions are:

* the original file
* a compressed file with gzip
* a file containing the original file name and its digest
* a compressed file containing the file name and its digest

> Note: We can specify a different output folder where `phoenix.digest` will put processed files. The first argument is the path where the static files are located.
```console
$ mix phoenix.digest priv/static -o www/public
Check your digested files at 'www/public'.
```

## Ecto Specific Mix Tasks

Newly generated Phoenix applications now include ecto and postgrex as dependencies by default (which is to say, unless we use the `--no-ecto` flag with `phoenix.new`). With those dependencies come mix tasks to take care of common ecto operations. Let's see which tasks we get out of the box.

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
The database for HelloPhoenix.Repo has been created.
```

If we happen to have another repo called `OurCustom.Repo` that we want to create the database for, we can run this.

```console
$ mix ecto.create -r OurCustom.Repo
The database for OurCustom.Repo has been created.
```

There are a few things that can go wrong with `ecto.create`. If our Postgres database doesn't have a "postgres" role (user), we'll get an error like this one.

```console
$ mix ecto.create
** (Mix) The database for HelloPhoenix.Repo couldn't be created, reason given: psql: FATAL:  role "postgres" does not exist
```

We can fix this by creating the "postgres" role with the permissions needed to log in and create a database.

```console
=# CREATE ROLE postgres LOGIN CREATEDB;
CREATE ROLE
```

If the "postgres" role does not have permission to log in to the application, we'll get this error.

```console
$ mix ecto.create
** (Mix) The database for HelloPhoenix.Repo couldn't be created, reason given: psql: FATAL:  role "postgres" is not permitted to log in
```

To fix this, we need to change the permissions on our "postgres" user to allow login.

```console
=# ALTER ROLE postgres LOGIN;
ALTER ROLE
```

If the "postgres" role does not have permission to create a database, we'll get this error.

```console
$ mix ecto.create
** (Mix) The database for HelloPhoenix.Repo couldn't be created, reason given: ERROR:  permission denied to create database
```

To fix this, we need to change the permissions on our "postgres" user to allow database creation.

```console
=# ALTER ROLE postgres CREATEDB;
ALTER ROLE
```

#### `ecto.drop`

This task will drop the database specified in our repo. By default it will look for the repo named after our application (the one generated with our app unless we opted out of ecto). It will not prompt us to check if we're sure we want to drop the db, so do exercise caution.

```console
$ mix ecto.drop
The database for HelloPhoenix.Repo has been dropped.
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
(typically in lib/hello_phoenix.ex):

worker(OurCustom.Repo, [])
```

Notice that this task has updated `config/config.exs`. If we take a look, we'll see this extra configuration block for our new repo.

```elixir
. . .
config :hello_phoenix, OurCustom.Repo,
adapter: Ecto.Adapters.Postgres,
database: "hello_phoenix_repo",
username: "user",
password: "pass",
hostname: "localhost"
. . .
```

Of course, we'll need to change the login credentials to match what our database expects. We'll also need to change the config for other environments.

We certainly should follow the instructions and add our new repo to our supervision tree. In our `HelloPhoenix` application, we would open up `lib/hello_phoenix.ex`, and add our repo as a worker to the `children` list.

```elixir
. . .
children = [
  # Start the endpoint when the application starts
  supervisor(HelloPhoenix.Endpoint, []),
  # Start the Ecto repository
  worker(HelloPhoenix.Repo, []),
  # Here you could define other workers and supervisors as children
  # worker(HelloPhoenix.Worker, [arg1, arg2, arg3]),
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
defmodule HelloPhoenix.Repo.Migrations.AddCommentsTable do
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

For more infomation on ecto's migration dsl, please see the [ecto migration docs](http://hexdocs.pm/ecto/Ecto.Migration.html).

That's it! We're ready to run our migration.

#### `ecto.migrate`

Once we have our migration module ready, we can simply run `mix ecto.migrate` to have our changes applied to the database.

```console
$ mix ecto.migrate
[info] == Running HelloPhoenix.Repo.Migrations.AddCommentsTable.change/0 forward
[info] create table comments
[info] == Migrated in 0.1s
```

When we first run `ecto.migrate`, it will create a table for us called `schema_migrations`. This will keep track of all the migrations which we run by storing the timestamp portion of the migration's filename.

Here's what the `schema_migrations` table looks like.

```console
hello_phoenix_dev=# select * from schema_migrations;
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
[info] == Running HelloPhoenix.Repo.Migrations.CreatePost.change/0 forward
[info] create table posts
[info] == Migrated in 0.0s
[info] == Running HelloPhoenix.Repo.Migrations.AddCommentsTable.change/0 forward
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
[info] == Running HelloPhoenix.Repo.Migrations.AddCommentsTable.change/0 backward
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

Inside that directory, let's create a new file, `hello_phoenix.greeting.ex`, that looks like this.

```elixir
defmodule Mix.Tasks.HelloPhoenix.Greeting do
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

The first thing we need to do is name our module. In order to properly namespace it, we begin with `Mix.Tasks`. We'd like to invoke this as `mix hello_phoenix.greeting`, so we complete the module name with
`HelloPhoenix.Greeting`.

The `use Mix.Task` line clearly brings in functionality from mix that makes this module behave as a mix task.

The `@shortdoc` module attribute holds a string which will describe our task when users invoke `mix help`.

`@moduledoc` serves the same function that it does in any module. It's where we can put long-form documentation and doctests, if we have any.

The `run/1` function is the critical heart of any mix task. It's the function that does all the work when users invoke our task. In ours, all we do is send a greeting from our app, but we can implement our `run/1` function to do whatever we need it to. Note that `Mix.shell.info/1` is the preferred way to print text back out to the user.

Of course, our task is just a module, so we can define other private functions as needed to support our `run/1` function.

Now that we have our task module defined, our next step is to compile the application.

```console
$ mix compile
Compiled lib/tasks/hello_phoenix.greeting.ex
Generated hello_phoenix.app
```

Now our new task should be visible to `mix help`.

```console
$ mix help | grep hello
mix hello_phoenix.greeting # Sends a greeting to us from Hello Phoenix
```

Notice that `mix help` displays the text we put into the `@shortdoc` along with the name of our task.

So far, so good, but does it work?

```console
$ mix hello_phoenix.greeting
Greetings from the Hello Phoenix Application!
```

Indeed it does.
