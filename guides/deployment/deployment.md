# Introduction to Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](up_and_running.html) to create a basic application to work with.

When preparing an application for deployment, there are three main steps:

  * Handling of your application secrets
  * Compiling your application assets
  * Starting your server in production

In this guide, we will learn how to get the production environment running locally. You can use the same techniques in this guide to run your application in production, but depending on your deployment infrastructure, extra steps will be necessary.

As an example of deploying to other infrastructures, we also discuss three different approaches in our guides: using [Elixir's releases](releases.html) with `mix release`, [using Gigalixir](gigalixir.html), and [using Heroku](heroku.html). We've also included links to deploying Phoenix on other platforms under [Community Deployment Guides](#community-deployment-guides). Finally, the release guide has a sample Dockerfile you can use if you prefer to deploy with container technologies.

Let's explore those steps above one by one.

## Handling of your application secrets

All Phoenix applications have data that must be kept secure, for example, the username and password for your production database, and the secret Phoenix uses to sign and encrypt important information. The general recommendation is to keep those in environment variables and load them into your application. This is done in `config/runtime.exs` (formerly `config/prod.secret.exs`), which is responsible for loading secrets and configuration from environment variables.

Therefore, you need to make sure the proper relevant variables are set in production:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Do not copy those values directly, set `SECRET_KEY_BASE` according to the result of `mix phx.gen.secret` and `DATABASE_URL` according to your database address.

If for some reason you do not want to rely on environment variables, you can hard code the secrets in your `config/runtime.exs` (formerly `config/prod.secret.exs`), but make sure not to check the file into your version control system.

With your secret information properly secured, it is time to configure assets!

Before taking this step, we need to do one bit of preparation. Since we will be readying everything for production, we need to do some setup in that environment by getting our dependencies and compiling.

```console
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
```

## Compiling your application assets

This step is required only if you have static assets like images, JavaScript, stylesheets and more in your Phoenix applications. By default, Phoenix uses webpack, and that's what we are going to explore.

Compilation of static assets happens in two steps:

```console
$ npm run deploy --prefix ./assets
$ MIX_ENV=prod mix phx.digest
Check your digested files at "priv/static".
```

*Note:* the `--prefix` flag on `npm` may not work on Windows. If so, replace the first command by `cd assets && npm run deploy && cd ..`.

And that is it! The first command builds the assets and the second generates digests as well as a cache manifest file so Phoenix can quickly serve assets in production.

Keep in mind that, if you by any chance forget to run the steps above, Phoenix will show an error message:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:50:18.732 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
10:50:18.735 [error] Could not find static manifest at "my_app/_build/prod/lib/foo/priv/static/cache_manifest.json". Run "mix phx.digest" after building your static files or remove the configuration from "config/prod.exs".
```

The error message is quite clear: it says Phoenix could not find a static manifest. Just run the commands above to fix it or, if you are not serving or don't care about assets at all, you can just remove the `cache_static_manifest` configuration from `config/prod.exs`.

## Starting your server in production

To run Phoenix in production, we need to set the `PORT` and `MIX_ENV` environment variables when invoking `mix phx.server`:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:59:19.136 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
```

To run in detached mode so that the Phoenix server does not stop and continues to run even if you close the terminal:

```console
$ PORT=4001 MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
```

In case you get an error message, please read it carefully, and open up a bug report if it is still not clear how to address it.

You can also run your application inside an interactive shell:

```console
$ PORT=4001 MIX_ENV=prod iex -S mix phx.server
10:59:19.136 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
```

## Putting it all together

The previous sections give an overview about the main steps required to deploy your Phoenix application. In practice, you will end-up adding steps of your own as well. For example, if you are using a database, you will also want to run `mix ecto.migrate` before starting the server to ensure your database is up to date.

Overall, here is a script you can use as a starting point:

```console
# Initial setup
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compile assets
$ npm run deploy --prefix ./assets
$ MIX_ENV=prod mix phx.digest

# Custom tasks (like DB migrations)
$ MIX_ENV=prod mix ecto.migrate

# Finally run the server
$ PORT=4001 MIX_ENV=prod mix phx.server
```

And that's it. Next you can use one of our official guides to deploy:

  * [with Elixir's releases](releases.html)
  * [to Gigalixir](gigalixir.html), an Elixir-centric Platform as a Service (PaaS)
  * and [to Heroku](heroku.html), one of the most popular PaaS.

## Community Deployment Guides

  * [Render](https://render.com) has first class support for Phoenix applications. There are guides for hosting Phoenix with [Mix releases](https://render.com/docs/deploy-phoenix), [Distillery](https://render.com/docs/deploy-phoenix-distillery), and as a [Distributed Elixir Cluster](https://render.com/docs/deploy-elixir-cluster).
