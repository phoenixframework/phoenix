# Introduction to Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](up_and_running.html) to create a basic application to work with.

When preparing an application for deployment, there are three main steps:

  * Handling of your application secrets
  * Compiling your application assets
  * Starting your server in production

How those are exactly handled depends on your deployment infrastructure. We have included a guide specific to [Heroku](heroku.html), and for anyone not using Heroku, we recommend using [Distillery](https://github.com/bitwalker/distillery) ([guide for using Distillery with Phoenix](https://hexdocs.pm/distillery/guides/phoenix_walkthrough.html)).

In any case, this chapter provides a general overview of the deployment steps, which will be useful regardless of your infrastructure or if you want to run in production locally.

Let's explore those steps above one by one.

## Handling of your application secrets

All Phoenix applications have data that must be kept secure, for example, the username and password for your production database, and the secret Phoenix uses to sign and encrypt important information. The general recommendation is to keep those in environment variables and load them into your application. This is done in `config/prod.secret.exs`, which is responsible for loading secrets and configuration from environment variables.

Therefore, you need to make sure the proper relevant variables are set in production:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Do not copy those values directly, set `SECRET_KEY_BASE` according to the result of `mix phx.gen.secret` and `DATABASE_URL` according to your database address.

If for some reason you do not want to rely on environment variables, you can hard code the secrets in your `config/prod.secret.exs`, but make sure not to check the file into your version control system.

With your secret information properly secured, it is time to configure assets!
Before taking this step, we need to do one bit of preparation.
Since we will be readying everything for production, we need to do some setup in that environment by getting our dependencies and compiling.

```console
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
```

## Compiling your application assets

This step is required only if you have static assets like images, JavaScript, stylesheets and more in your Phoenix applications. By default, Phoenix uses webpack, and that's what we are going to explore.

Compilation of static assets happens in two steps:

```console
$ npm run deploy --prefix ./assets

$ mix phx.digest

Check your digested files at "priv/static".
```

And that is it! The first command builds the assets and the second generates digests as well as a cache manifest file so Phoenix can quickly serve assets in production.

Keep in mind that, if you by any chance forget to run the steps above, Phoenix will show an error message:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:50:18.732 [info] Running MyApp.Endpoint with Cowboy on http://example.com
10:50:18.735 [error] Could not find static manifest at "my_app/_build/prod/lib/foo/priv/static/cache_manifest.json". Run "mix phx.digest" after building your static files or remove the configuration from "config/prod.exs".
```

The error message is quite clear: it says Phoenix could not find a static manifest. Just run the commands above to fix it or, if you are not serving or don't care about assets at all, you can just remove the `cache_static_manifest` configuration from `config/prod.exs`.

## Starting your server in production

To run Phoenix in production, we need to set the `PORT` and `MIX_ENV` environment variables when invoking `mix phx.server`:

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

Overall, here is a script you can use as a starting point:

```elixir
# Initial setup
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compile assets
$ npm run deploy --prefix ./assets

$ mix phx.digest

# Custom tasks (like DB migrations)
$ MIX_ENV=prod mix ecto.migrate

# Finally run the server
$ PORT=4001 MIX_ENV=prod mix phx.server
```
