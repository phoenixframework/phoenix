# Mix Tasks

There are currently a number of built-in Phoenix-specific and Ecto-specific mix tasks available to us within a newly-generated application. We can also create our own application specific tasks.

> Note to learn more about `mix`, you can read Elixir's official [Introduction to Mix](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html).

## Phoenix tasks

```console
➜ mix help --search "phx"
mix local.phx          # Updates the Phoenix project generator locally
mix phx                # Prints Phoenix help information
mix phx.digest         # Digests and compresses static files
mix phx.digest.clean   # Removes old versions of static assets.
mix phx.gen.auth       # Generates authentication logic for a resource
mix phx.gen.cert       # Generates a self-signed certificate for HTTPS testing
mix phx.gen.channel    # Generates a Phoenix channel
mix phx.gen.context    # Generates a context with functions around an Ecto schema
mix phx.gen.embedded   # Generates an embedded Ecto schema file
mix phx.gen.html       # Generates controller, views, and context for an HTML resource
mix phx.gen.json       # Generates controller, views, and context for a JSON resource
mix phx.gen.presence   # Generates a Presence tracker
mix phx.gen.schema     # Generates an Ecto schema and migration file
mix phx.gen.secret     # Generates a secret
mix phx.new            # Creates a new Phoenix application
mix phx.new.ecto       # Creates a new Ecto project within an umbrella project
mix phx.new.web        # Creates a new Phoenix web project within an umbrella project
mix phx.routes         # Prints all routes
mix phx.server         # Starts applications and their servers
```

We have seen all of these at one point or another in the guides, but having all the information about them in one place seems like a good idea.

We will cover all Phoenix Mix tasks, except `phx.new`, `phx.new.ecto`, and `phx.new.web`, which are part of the Phoenix installer. You can learn more about them or any other task by calling `mix help TASK`.

### `mix phx.gen.html`

Phoenix offers the ability to generate all the code to stand up a complete HTML resource - ecto migration, ecto context, controller with all the necessary actions, view, and templates. This can be a tremendous timesaver. Let's take a look at how to make this happen.

The `mix phx.gen.html` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

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
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

When `mix phx.gen.html` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/posts", PostController

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Important: If we don't do this, we will see the following warnings in our logs, and our application will error when trying to execute the function.

```console
$ mix phx.server
Compiling 17 files (.ex)

warning: function HelloWeb.Router.Helpers.post_path/3 is undefined or private
  lib/hello_web/controllers/post_controller.ex:22:
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
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

It will tell us we need to add a line to our router file, but since we skipped the schema, it won't mention anything about `ecto.migrate`.

### `mix phx.gen.json`

Phoenix also offers the ability to generate all the code to stand up a complete JSON resource - ecto migration, ecto schema, controller with all the necessary actions and view. This command will not create any template for the app.

The `mix phx.gen.json` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes. The module name we pass in must conform to the Elixir rules of module naming, following proper capitalization.

```console
$ mix phx.gen.json Blog Post posts title:string content:string
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/views/post_view.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello_web/views/changeset_view.ex
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/blog/post.ex
* creating priv/repo/migrations/20170906153323_create_posts.exs
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
```

When `mix phx.gen.json` is done creating files, it helpfully tells us that we need to add a line to our router file as well as run our ecto migrations.

```console
Add the resource to your :api scope in lib/hello_web/router.ex:

    resources "/posts", PostController, except: [:new, :edit]

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Important: If we don't do this, we'll get the following warning in our logs and the application will error when attempting to load the page:

```console
$ mix phx.server
Compiling 19 files (.ex)

warning: function HelloWeb.Router.Helpers.post_path/3 is undefined or private
  lib/hello_web/controllers/post_controller.ex:18
```

`mix phx.gen.json` also supports `--no-context`, `--no-schema`, and others, as in `mix phx.gen.html`.

### `mix phx.gen.context`

If we don't need a complete HTML/JSON resource and instead are only interested in a context, we can use the `mix phx.gen.context` task. It will generate a context, a schema, a migration and a test case.

The `mix phx.gen.context` task takes a number of arguments, the module name of the context, the module name of the schema, the resource name, and a list of column_name:type attributes.

```console
$ mix phx.gen.context Accounts User users name:string age:integer
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170906161158_create_users.exs
* creating lib/hello/accounts.ex
* injecting lib/hello/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs
```

> Note: If we need to namespace our resource we can simply namespace the first argument of the generator.

```console
* creating lib/hello/admin/accounts/user.ex
* creating priv/repo/migrations/20170906161246_create_users.exs
* creating lib/hello/admin/accounts.ex
* injecting lib/hello/admin/accounts.ex
* creating test/hello/admin/accounts/accounts_test.exs
* injecting test/hello/admin/accounts/accounts_test.exs
```

### `mix phx.gen.schema`

If we don't need a complete HTML/JSON resource and are not interested in generating or altering a context we can use the `mix phx.gen.schema` task. It will generate a schema, and a migration.

The `mix phx.gen.schema` task takes a number of arguments, the module name of the schema (which may be namespaced), the resource name, and a list of column_name:type attributes.

```console
$ mix phx.gen.schema Accounts.Credential credentials email:string:unique user_id:references:users
* creating lib/hello/accounts/credential.ex
* creating priv/repo/migrations/20170906162013_create_credentials.exs
```

### `mix phx.gen.auth`

Phoenix also offers the ability to generate all of the code to stand up a complete authentication system - ecto migration, phoenix context, controllers, templates, etc. This can be a huge timesaver, allowing you to quickly add authentication to your system and shift your focus back to the primary problems your application is trying to solve.

The `mix phx.gen.auth` task takes the following arguments: the module name of the context, the module name of the schema, and a plural version of the schema name used to generate database tables and route helpers.

Here is an example version of the command:

```console
$ mix phx.gen.auth Accounts User users
* creating priv/repo/migrations/20201205184926_create_users_auth_tables.exs
* creating lib/hello/accounts/user_notifier.ex
* creating lib/hello/accounts/user.ex
* creating lib/hello/accounts/user_token.ex
* creating lib/hello_web/controllers/user_auth.ex
* creating test/hello_web/controllers/user_auth_test.exs
* creating lib/hello_web/views/user_confirmation_view.ex
* creating lib/hello_web/templates/user_confirmation/new.html.eex
* creating lib/hello_web/controllers/user_confirmation_controller.ex
* creating test/hello_web/controllers/user_confirmation_controller_test.exs
* creating lib/hello_web/templates/layout/_user_menu.html.eex
* creating lib/hello_web/templates/user_registration/new.html.eex
* creating lib/hello_web/controllers/user_registration_controller.ex
* creating test/hello_web/controllers/user_registration_controller_test.exs
* creating lib/hello_web/views/user_registration_view.ex
* creating lib/hello_web/views/user_reset_password_view.ex
* creating lib/hello_web/controllers/user_reset_password_controller.ex
* creating test/hello_web/controllers/user_reset_password_controller_test.exs
* creating lib/hello_web/templates/user_reset_password/edit.html.eex
* creating lib/hello_web/templates/user_reset_password/new.html.eex
* creating lib/hello_web/views/user_session_view.ex
* creating lib/hello_web/controllers/user_session_controller.ex
* creating test/hello_web/controllers/user_session_controller_test.exs
* creating lib/hello_web/templates/user_session/new.html.eex
* creating lib/hello_web/views/user_settings_view.ex
* creating lib/hello_web/templates/user_settings/edit.html.eex
* creating lib/hello_web/controllers/user_settings_controller.ex
* creating test/hello_web/controllers/user_settings_controller_test.exs
* creating lib/hello/accounts.ex
* injecting lib/hello/accounts.ex
* creating test/hello/accounts_test.exs
* injecting test/hello/accounts_test.exs
* creating test/support/fixtures/accounts_fixtures.ex
* injecting test/support/fixtures/accounts_fixtures.ex
* injecting test/support/conn_case.ex
* injecting config/test.exs
* injecting mix.exs
* injecting lib/hello_web/router.ex
* injecting lib/hello_web/router.ex - imports
* injecting lib/hello_web/router.ex - plug
* injecting lib/hello_web/templates/layout/app.html.eex
```

When `mix phx.gen.auth` is done creating files, it helpfully tells us that we need to re-fetch our dependencies as well as run our ecto migrations.

```console
Please re-fetch your dependencies with the following command:

    mix deps.get

Remember to update your repository by running migrations:

  $ mix ecto.migrate
```

A more complete walk-through of how to get started with this generator is available in the [`mix phx.gen.auth` Guide](mix_phx_gen_auth.html).

### `mix phx.gen.channel`

This task will generate a basic Phoenix channel as well a test case for it. It takes the module name for the channel as argument:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs
```

When `mix phx.gen.channel` is done, it helpfully tells us that we need to add a channel route to our router file.

```console
Add the channel to your `lib/hello_web/channels/user_socket.ex` handler, for example:

    channel "rooms:lobby", HelloWeb.RoomChannel
```

### `mix phx.gen.presence`

This task will generate a Presence tracker. The module name can be passed as an argument,
`Presence` is used if no module name is passed.

```console
$ mix phx.gen.presence Presence
$ lib/hello_web/channels/presence.ex
```

### `mix phx.routes`

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

### `mix phx.server`

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

### `mix phx.digest`

This task does two things, it creates a digest for our static assets and then compresses them.

"Digest" here refers to an MD5 digest of the contents of an asset which gets added to the filename of that asset. This creates a sort of "fingerprint" for it. If the digest doesn't change, browsers and CDNs will use a cached version. If it does change, they will re-fetch the new version.

Before we run this task let's inspect the contents of two directories in our hello application.

First `priv/static` which should look similar to this:

```console
├── images
│   └── phoenix.png
└── robots.txt
```

And then `assets/` which should look similar to this:

```console
├── css
│   └── app.scss
├── js
│   └── app.js
└── vendor
    └── phoenix.js
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

> Note: We can specify a different output folder where `mix phx.digest` will put processed files. The first argument is the path where the static files are located.

```console
$ mix phx.digest priv/static -o www/public
Check your digested files at 'www/public'.
```

## Ecto tasks

Newly generated Phoenix applications now include ecto and postgrex as dependencies by default (which is to say, unless we use `mix phx.new` with the `--no-ecto` flag). With those dependencies come mix tasks to take care of common ecto operations. Let's see which tasks we get out of the box.

```console
$ mix help --search "ecto"
mix ecto               # Prints Ecto help information
mix ecto.create        # Creates the repository storage
mix ecto.drop          # Drops the repository storage
mix ecto.dump          # Dumps the repository database structure
mix ecto.gen.migration # Generates a new migration for the repo
mix ecto.gen.repo      # Generates a new repository
mix ecto.load          # Loads previously dumped database structure
mix ecto.migrate       # Runs the repository migrations
mix ecto.migrations    # Displays the repository migration status
mix ecto.rollback      # Rolls back the repository migrations
```

Note: We can run any of the tasks above with the `--no-start` flag to execute the task without starting the application.

### `mix ecto.create`

This task will create the database specified in our repo. By default it will look for the repo named after our application (the one generated with our app unless we opted out of ecto), but we can pass in another repo if we want.

Here's what it looks like in action.

```console
$ mix ecto.create
The database for Hello.Repo has been created.
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

Finally, if we happen to have another repo called `OurCustom.Repo` that we want to create the database for, we can run this.

```console
$ mix ecto.create -r OurCustom.Repo
The database for OurCustom.Repo has been created.
```

### `mix ecto.drop`

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

### `mix ecto.gen.repo`

Many applications require more than one data store. For each data store, we'll need a new repo, and we can generate them automatically with `ecto.gen.repo`.

If we name our repo `OurCustom.Repo`, this task will create it here `lib/our_custom/repo.ex`.

```console
$ mix ecto.gen.repo -r OurCustom.Repo
* creating lib/our_custom
* creating lib/our_custom/repo.ex
* updating config/config.exs
Don't forget to add your new repo to your supervision tree
(typically in lib/hello.ex):

    children = [
      ...,
      OurCustom.Repo,
      ...
    ]
```

Notice that this task has updated `config/config.exs`. If we take a look, we'll see this extra configuration block for our new repo.

```elixir
. . .
config :hello, OurCustom.Repo,
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
  # Start the Ecto repository
  Hello.Repo,
  # Our custom repo
  OurCustom.Repo,
  # Start the endpoint when the application starts
  HelloWeb.Endpoint,
]
. . .
```

### `mix ecto.gen.migration`

Migrations are a programmatic, repeatable way to affect changes to a database schema. Migrations are also just modules, and we can create them with the `ecto.gen.migration` task. Let's walk through the steps to create a migration for a new comments table.

We simply need to invoke the task with a `snake_case` version of the module name that we want. Preferably, the name will describe what we want the migration to do.

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
    timestamps()
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
ecto's migration dsl [ecto migration docs](https://hexdocs.pm/ecto_sql/Ecto.Migration.html).
For example, to alter an existing schema see the documentation on ecto’s
[`alter/2`](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#alter/2) function.

That's it! We're ready to run our migration.

### `mix ecto.migrate`

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
version        |     inserted_at
---------------+---------------------
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

The `--to` option will run all migrations up to and including given version.

```console
mix ecto.migrate --to 20150317170448
```

### `mix ecto.rollback`

The `ecto.rollback` task will reverse the last migration we have run, undoing the schema changes. `ecto.migrate` and `ecto.rollback` are mirror images of each other.

```console
$ mix ecto.rollback
[info] == Running Hello.Repo.Migrations.AddCommentsTable.change/0 backward
[info] drop table comments
[info] == Migrated in 0.0s
```

`ecto.rollback` will handle the same options as `ecto.migrate`, so `-n`, `--step`, `-v`, and `--to` will behave as they do for `ecto.migrate`.

## Creating our own Mix task

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
    Mix.shell().info("Greetings from the Hello Phoenix Application!")
  end

  # We can define other functions as needed here.
end
```

Let's take a quick look at the moving parts involved in a working mix task.

The first thing we need to do is name our module. All tasks must be defined in `Mix.Tasks` namespace. We'd like to invoke this as `mix hello.greeting`, so we complete the module name with
`Hello.Greeting`.

The `use Mix.Task` line brings in functionality from Mix that makes this module behave as a mix task.

The `@shortdoc` module attribute holds a string which will describe our task when users invoke `mix help`.

`@moduledoc` serves the same function that it does in any module. It's where we can put long-form documentation and doctests, if we have any.

The `run/1` function is the critical heart of any Mix task. It's the function that does all the work when users invoke our task. In ours, all we do is send a greeting from our app, but we can implement our `run/1` function to do whatever we need it to. Note that `Mix.shell().info/1` is the preferred way to print text back out to the user.

Of course, our task is just a module, so we can define other private functions as needed to support our `run/1` function.

Now that we have our task module defined, our next step is to compile the application.

```console
$ mix compile
Compiled lib/tasks/hello.greeting.ex
Generated hello.app
```

Now our new task should be visible to `mix help`.

```console
$ mix help --search hello
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
    Mix.Task.run("app.start")
    Mix.shell().info("Now I have access to Repo and other goodies!")
  end
  . . .
```
