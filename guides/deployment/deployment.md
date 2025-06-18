# Introduction to Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](up_and_running.html) to create a basic application to work with.

When preparing an application for deployment, there are three main steps:

  * Handling of your application secrets
  * Compiling your application assets
  * Starting your server in production

In this guide, we will learn how to get the production environment running locally. You can use the same techniques in this guide to run your application in production, but depending on your deployment infrastructure, extra steps will be necessary.

As an example of deploying to other infrastructures, we also discuss four different approaches in our guides: using [Elixir's releases](releases.html) with `mix release`, [using Gigalixir](gigalixir.html), [using Fly](fly.html), and [using Heroku](heroku.html). We've also included links to deploying Phoenix on other platforms under [Community Deployment Guides](#community-deployment-guides). Finally, the release guide has a sample Dockerfile you can use if you prefer to deploy with container technologies.

Let's explore those steps above one by one.

## Handling of your application secrets

All Phoenix applications have data that must be kept secure, for example, the username and password for your production database, and the secret Phoenix uses to sign and encrypt important information. The general recommendation is to keep those in environment variables and load them into your application. This is done in `config/runtime.exs` (formerly `config/prod.secret.exs` or `config/releases.exs`), which is responsible for loading secrets and configuration from environment variables at boot time.

Therefore, you need to make sure the proper relevant variables are set in production:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Do not copy those values directly, set `SECRET_KEY_BASE` according to the result of `mix phx.gen.secret` and `DATABASE_URL` according to your database address.

If for some reason you do not want to rely on environment variables, you can hard code the secrets in your `config/runtime.exs` but make sure not to check the file into your version control system.

With your secret information properly secured, it is time to configure assets!

Before taking this step, we need to do one bit of preparation. Since we will be readying everything for production, we need to do some setup in that environment by getting our dependencies and compiling.

```console
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
```

## Compiling your application assets

This step is required only if you have compilable assets like JavaScript and stylesheets. By default, Phoenix uses `esbuild` but everything is encapsulated in a single `mix assets.deploy` task defined in your `mix.exs`:

```console
$ MIX_ENV=prod mix assets.deploy
Check your digested files at "priv/static".
```

And that is it! The Mix task by default builds the assets and then generates digests with a cache manifest file so Phoenix can quickly serve assets in production.

> Note: if you run the task above in your local machine, it will generate many digested assets in `priv/static`. You can prune them by running `mix phx.digest.clean --all`.

Keep in mind that, if you by any chance forget to run the steps above, Phoenix will show an error message:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:50:18.732 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
10:50:18.735 [error] Could not find static manifest at "my_app/_build/prod/lib/foo/priv/static/cache_manifest.json". Run "mix phx.digest" after building your static files or remove the configuration from "config/prod.exs".
```

The error message is quite clear: it says Phoenix could not find a static manifest. Just run the commands above to fix it or, if you are not serving or don't care about assets at all, you can just remove the `cache_static_manifest` configuration from your config.

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
$ MIX_ENV=prod mix assets.deploy

# Custom tasks (like DB migrations)
$ MIX_ENV=prod mix ecto.migrate

# Finally run the server
$ PORT=4001 MIX_ENV=prod mix phx.server
```

And that's it. Next, you can use one of our official guides to deploy:

  * [with Elixir's releases](releases.html)
  * [to Gigalixir](gigalixir.html), an Elixir-centric Platform as a Service (PaaS)
  * [to Fly.io](fly.html), a PaaS that deploys your servers close to your users with built-in distribution support
  * and [to Heroku](heroku.html), one of the most popular PaaS.

## Clustering and Long-Polling Transports

Phoenix supports two types of transports for its Socket implementation: WebSocket, and Long-Polling. When generating a Phoenix project, you can see the default configuration set in the generated `endpoint.ex` file:

```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```

This configuration tells Phoenix that both the WebSocket and the Long-Polling options are available, and based on the client's network conditions, Phoenix will first attempt to connect to the WebSocket, falling back to the Long-Poll option after the configured timeout found in the generated `app.js` file:

```javascript
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})
```

If you are running more than one machine in production, which is the recommended approach in most cases, this automatic fallback comes with an important caveat. If you want Long-Polling to work properly, your application must either:

1. Utilize the Erlang VM's clustering capabilities, so the default `Phoenix.PubSub` adapter can broadcast messages across nodes

2. Choose a different `Phoenix.PubSub` adapter (such as `Phoenix.PubSub.Redis`)

3. Or your deployment option must implement sticky sessions - ensuring that all requests for a specific session go to the same machine

The reason for this is simple. While a WebSocket is a long-lived open connection to the same machine, long-polling works by opening a request to the server, waiting for a timeout or until the open request is fulfilled, and repeating this process. In order to preserve the state of the user's connected socket and to preserve the behaviour of a socket being long-lived, the user's process is kept alive, and each long-poll request attempts to find the user's stateful process. If the stateful process is not reachable, every request will create a new process and a new state, thereby breaking the fact that the socket is long-lived and stateful.

## Community Deployment Guides

  * [Render](https://render.com) has first class support for Phoenix applications. There are guides for hosting Phoenix with [Mix releases](https://render.com/docs/deploy-phoenix) and as a [Distributed Elixir Cluster](https://render.com/docs/deploy-elixir-cluster).
  * [Railway](https://railway.com) also provides support for Phoenix applications using [Mix releases](https://docs.railway.com/guides/phoenix).
