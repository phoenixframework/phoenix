# Introduction to Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](up_and_running.html) to create a basic application to work with.

When preparing an application for deployment, there are three main steps:

  * Handling of your application secrets
  * Compiling your application assets
  * Starting your server in production

How those are exactly handled depends on your deployment infrastructure. We have included a guide specific to [Heroku](heroku.html), and for anyone not using Heroku, we recommend using  [Distillery](https://github.com/bitwalker/distillery).

In any case, this chapter provides a general overview of the deployment steps, which will be useful regardless of your infrastructure or if you want to run in production locally.

Let's explore those steps above one by one.

> Note: this guide assumes you are using at least Elixir v1.0.4, which brought some improvements on how applications are compiled and are optimized for the production environment

## Handling of your application secrets

All Phoenix applications have data that must be kept secure, for example, the username and password for your production database, and the secret Phoenix uses to sign and encrypt important information. This data is typically kept in `config/prod.secret.exs` and by default it is not checked into your version control system.

Therefore, the first step is to get this data into your production machine. Here is the template shipped with new applications:

```elixir
use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.

# You can generate a new secret by running:
#
#     mix phoenix.gen.secret
config :foo, Foo.Endpoint,
  secret_key_base: "A LONG SECRET"

# Configure your database
config :foo, Foo.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "foo_prod",
  size: 20 # The amount of database connections in the pool
```

There are different ways to get this data into production. One option is to replace the data above by environment variables and set those environment variables in your production machine. This is the step that we follow [in the Heroku guides](heroku.html).

Another approach is to configure the file above and place it in your production machines apart from your code checkout, for example, at "/var/config.prod.exs". After doing so, you will have to import it from `config/prod.exs`. Search for the `import_config` line and replace it by the proper path:

```elixir
import_config "/var/config.prod.exs"
```

With your secret information properly secured, it is time to configure assets!
Before taking this step, we need to do one bit of preparation.
Since we will be readying everything for production, we need to do some setup in that environment by getting our dependencies and compiling.

```console
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
```

## Compiling your application assets

This step is required only if you have static assets like images, JavaScript, stylesheets and more in your Phoenix applications. By default, Phoenix uses brunch, and that's what we are going to explore.

Compilation of static assets happens in two steps:

```console
$ brunch build --production

$ mix phx.digest

Check your digested files at "priv/static".
```

And that is it! The first command builds the assets and the second generates digests as well as a cache manifest file so Phoenix can quickly serve assets in production.

Keep in mind that, if you by any chance forget to run the steps above, Phoenix will show an error message:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:50:18.732 [info] Running MyApp.Endpoint with Cowboy on http://example.com
10:50:18.735 [error] Could not find static manifest at "my_app/_build/prod/lib/foo/priv/static/cache_manifest.json". Run "mix phoenix.digest" after building your static files or remove the configuration from "config/prod.exs".
```

The error message is quite clear: it says Phoenix could not find a static manifest. Just run the commands above to fix it or, if you are not serving or don't care about assets at all, you can just remove the `cache_static_manifest` configuration from `config/prod.exs`.

## Starting your server in production

To run Phoenix in production, we need to set the `PORT` and `MIX_ENV` environment variables when invoking `mix phoenix.server`:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:59:19.136 [info] Running MyApp.Endpoint with Cowboy on http://example.com
```

In case you get an error message, please read it carefully, and open up a bug report if it is still not clear how to address it.

You can also run your application inside an interactive shell:

```console
$ PORT=4001 MIX_ENV=prod iex -S mix phx.server
10:59:19.136 [info] Running MyApp.Endpoint with Cowboy on http://example.com
```

Or run it detached from the iex console. This effectively daemonizes the process so it can run independently in the background:

```elixir
MIX_ENV=prod PORT=4001 elixir --detached -S mix do compile, phx.server
```

Running the application in detached mode allows us to keep the application running even after we terminate the shell connection with the server.

## Putting it all together

The previous sections give an overview about the main steps required to deploy your Phoenix application. In practice, you will end-up adding steps of your own as well. For example, if you are using a database, you will also want to run `mix ecto.migrate` before starting the server to ensure your database is up to date.

Overall, here is a script you can use as starting point:

```elixir
# Initial setup
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compile assets
$ brunch build --production

$ mix phx.digest

# Custom tasks (like DB migrations)
$ MIX_ENV=prod mix ecto.migrate

# Finally run the server
$ PORT=4001 MIX_ENV=prod mix phx.server
```
