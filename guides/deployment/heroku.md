# Deploying on Heroku

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](https://hexdocs.pm/phoenix/up_and_running.html).

## Goals

Our main goal for this guide is to get a Phoenix application running on Heroku.

## Limitations

Heroku is a great platform and Elixir performs well on it. However, you may run into limitations if you plan to leverage advanced features provided by Elixir and Phoenix, such as:

- Connections are limited.
  - Heroku [limits the number of simultaneous connections](https://devcenter.heroku.com/articles/http-routing#request-concurrency) as well as the [duration of each connection](https://devcenter.heroku.com/articles/limits#http-timeouts). It is common to use Elixir for real-time apps which need lots of concurrent, persistent connections, and Phoenix is capable of [handling over 2 million connections on a single server](https://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections).

- Distributed clustering is not possible.
  - Heroku [firewalls dynos off from one another](https://devcenter.heroku.com/articles/dynos#networking). This means things like [distributed Phoenix channels](https://dockyard.com/blog/2016/01/28/running-elixir-and-phoenix-projects-on-a-cluster-of-nodes) and [distributed tasks](https://hexdocs.pm/elixir/distributed-tasks.html) will need to rely on something like Redis instead of Elixir's built-in distribution.

- In-memory state such as those in [Agents](https://hexdocs.pm/elixir/agents.html), [GenServers](https://hexdocs.pm/elixir/genservers.html), and [ETS](https://hexdocs.pm/elixir/erlang-term-storage.html) will be lost every 24 hours.
  - Heroku [restarts dynos](https://devcenter.heroku.com/articles/dynos#restarting) every 24 hours regardless of whether the node is healthy.

- [The built-in observer](https://hexdocs.pm/elixir/debugging.html#observer) can't be used with Heroku.
  - Heroku does allow for connection into your dyno, but you won't be able to use the observer to watch the state of your dyno.

If you are just getting started, or you don't expect to use the features above, Heroku should be enough for your needs. For instance, if you are migrating an existing application running on Heroku to Phoenix, keeping a similar set of features, Elixir will perform just as well or even better than your current stack.

If you want a platform-as-a-service without these limitations, try [Gigalixir](gigalixir.html). If you would rather deploy to a cloud platform, such as EC2, Google Cloud, etc, consider using `mix release`.

## Steps

Let's separate this process into a few steps, so we can keep track of where we are.

- Initialize Git repository
- Sign up for Heroku
- Install the Heroku Toolbelt
- Create and set up Heroku application
- Make our project ready for Heroku
- Deploy time!
- Useful Heroku commands

## Initializing Git repository

[Git](https://git-scm.com/) is a popular decentralized revision control system and is also used to deploy apps to Heroku.

Before we can push to Heroku, we'll need to initialize a local Git repository and commit our files to it. We can do so by running the following commands in our project directory:

```console
$ git init
$ git add .
$ git commit -m "Initial commit"
```

Heroku offers some great information on how it is using Git [here](https://devcenter.heroku.com/articles/git#prerequisites-install-git-and-the-heroku-cli).

## Signing up for Heroku

Signing up to Heroku is very simple, just head over to [https://signup.heroku.com/](https://signup.heroku.com/) and fill in the form.

The Free plan will give us one web [dyno](https://devcenter.heroku.com/articles/dynos) and one worker dyno, as well as a PostgreSQL and Redis instance for free.

These are meant to be used for testing and development, and come with some limitations. In order to run a production application, please consider upgrading to a paid plan.

## Installing the Heroku Toolbelt

Once we have signed up, we can download the correct version of the Heroku Toolbelt for our system [here](https://toolbelt.heroku.com/).

The Heroku CLI, part of the Toolbelt, is useful to create Heroku applications, list currently running dynos for an existing application, tail logs or run one-off commands (mix tasks for instance).

## Create and Set Up Heroku Application

There are two different ways to deploy a Phoenix app on Heroku. We could use Heroku buildpacks or their container stack. The difference between these two approaches is in how we tell Heroku to treat our build. In buildpack case, we need to update our apps configuration on Heroku to use Phoenix/Elixir specific buildpacks. On container approach, we have more control on how we want to set up our app, and we can define our container image using `Dockerfile` and `heroku.yml`. This section will explore the buildpack approach. In order to use Dockerfile, it is often recommended to convert our app to use releases, which we will describe later on.

### Create Application

A [buildpack](https://devcenter.heroku.com/articles/buildpacks) is a convenient way of packaging framework and/or runtime support. Phoenix requires 2 buildpacks to run on Heroku, the first adds basic Elixir support and the second adds Phoenix specific commands.

With the Toolbelt installed, let's create the Heroku application. We will do so using the latest available version of the [Elixir buildpack](https://github.com/HashNuke/heroku-buildpack-elixir):

```console
$ heroku create --buildpack hashnuke/elixir
Creating app... done, ⬢ mysterious-meadow-6277
Setting buildpack to hashnuke/elixir... done
https://mysterious-meadow-6277.herokuapp.com/ | https://git.heroku.com/mysterious-meadow-6277.git
```

> Note: the first time we use a Heroku command, it may prompt us to log in. If this happens, just enter the email and password you specified during signup.

> Note: the name of the Heroku application is the random string after "Creating" in the output above (mysterious-meadow-6277). This will be unique, so expect to see a different name from "mysterious-meadow-6277".

> Note: the URL in the output is the URL to our application. If we open it in our browser now, we will get the default Heroku welcome page.

> Note: if we hadn't initialized our Git repository before we ran the `heroku create` command, we wouldn't have our Heroku remote repository properly set up at this point. We can set that up manually by running: `heroku git:remote -a [our-app-name].`

The buildpack uses a predefined Elixir and Erlang version, but to avoid surprises when deploying, it is best to explicitly list the Elixir and Erlang version we want in production to be the same we are using during development or in your continuous integration servers. This is done by creating a config file named `elixir_buildpack.config` in the root directory of your project with your target version of Elixir and Erlang:

```console
# Elixir version
elixir_version=1.14.0

# Erlang version
# https://github.com/HashNuke/heroku-buildpack-elixir-otp-builds/blob/master/otp-versions
erlang_version=24.3

# Invoke assets.deploy defined in your mix.exs to deploy assets with esbuild
# Note we nuke the esbuild executable from the image
hook_post_compile="eval mix assets.deploy && rm -f _build/esbuild*"
```

Finally, let's tell the build pack how to start our webserver. Create a file named `Procfile` at the root of your project:

```console
web: mix phx.server
```

### Optional: Node, npm, and the Phoenix Static buildpack

By default, Phoenix uses `esbuild` and manages all assets for you. However, if you are using `node` and `npm`, you will need to install the [Phoenix Static buildpack](https://github.com/gjaldon/heroku-buildpack-phoenix-static) to handle them:

```console
$ heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Buildpack added. Next release on mysterious-meadow-6277 will use:
  1. https://github.com/HashNuke/heroku-buildpack-elixir.git
  2. https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
```

When using this buildpack, you want to delegate all asset bundling to `npm`. So you must remove the `hook_post_compile` configuration from your `elixir_buildpack.config` and move it to the deploy script of your `assets/package.json`. Something like this:

```javascript
{
  ...
  "scripts": {
    "deploy": "cd .. && mix assets.deploy && rm -f _build/esbuild*"
  }
  ...
}
```

The Phoenix Static buildpack uses a predefined Node.js version, but to avoid surprises when deploying, it is best to explicitly list the Node.js version we want in production to be the same we are using during development or in your continuous integration servers. This is done by creating a config file named `phoenix_static_buildpack.config` in the root directory of your project with your target version of Node.js:

```text
# Node.js version
node_version=10.20.1
```

Please refer to the [configuration section](https://github.com/gjaldon/heroku-buildpack-phoenix-static#configuration) for full details. You can make your own custom build script, but for now we will use the [default one provided](https://github.com/gjaldon/heroku-buildpack-phoenix-static/blob/master/compile).

Finally, note that since we are using multiple buildpacks, you might run into an issue where the sequence is out of order (the Elixir buildpack needs to run before the Phoenix Static buildpack). [Heroku's docs](https://devcenter.heroku.com/articles/using-multiple-buildpacks-for-an-app) explain this better, but you will need to make sure the Phoenix Static buildpack comes last.

## Making our Project ready for Heroku

Every new Phoenix project ships with a config file `config/runtime.exs` (formerly `config/prod.secret.exs`) which loads configuration and secrets from [environment variables](https://devcenter.heroku.com/articles/config-vars). This aligns well with Heroku best practices ([12-factor apps](https://12factor.net/)), so the only work left for us to do is to configure URLs and SSL.

First let's tell Phoenix to only use the SSL version of the website. Find the endpoint config in your `config/prod.exs`:

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [port: 443, scheme: "https"],
```

... and add `force_ssl`

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [port: 443, scheme: "https"],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
```

`force_ssl` need to be set here because it is a _compile_ time config. It will not work when set from `runtime.exs`.

Then in your `config/runtime.exs` (formerly `config/prod.secret.exs`):

... add `host`

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [host: host, port: 443, scheme: "https"]
```

and uncomment the `# ssl: true,` line in your repository configuration. It will look like this:

```elixir
config :hello, Hello.Repo,
  ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

Finally, if you plan on using websockets, then we will need to decrease the timeout for the websocket transport in `lib/hello_web/endpoint.ex`. If you do not plan on using websockets, then leaving it set to false is fine. You can find further explanation of the options available at the [documentation](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).

```elixir
defmodule HelloWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello

  socket "/socket", HelloWeb.UserSocket,
    websocket: [timeout: 45_000]

  ...
end
```

Also set the host in Heroku:

```console
$ heroku config:set PHX_HOST="mysterious-meadow-6277.herokuapp.com"
```

This ensures that any idle connections are closed by Phoenix before they reach Heroku's 55-second timeout window.

## Creating Environment Variables in Heroku

The `DATABASE_URL` config var is automatically created by Heroku when we add the [Heroku Postgres add-on](https://elements.heroku.com/addons/heroku-postgresql). We can create the database via the Heroku toolbelt:

```console
$ heroku addons:create heroku-postgresql:mini
```

Now we set the `POOL_SIZE` config var:

```console
$ heroku config:set POOL_SIZE=18
```

This value should be just under the number of available connections, leaving a couple open for migrations and mix tasks. The mini database allows 20 connections, so we set this number to 18. If additional dynos will share the database, reduce the `POOL_SIZE` to give each dyno an equal share.

When running a mix task later (after we have pushed the project to Heroku) you will also want to limit its pool size like so:

```console
$ heroku run "POOL_SIZE=2 mix hello.task"
```

So that Ecto does not attempt to open more than the available connections.

We still have to create the `SECRET_KEY_BASE` config based on a random string. First, use `mix phx.gen.secret` to get a new secret:

```console
$ mix phx.gen.secret
xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53
```

Your random string will be different; don't use this example value.

Now set it in Heroku:

```console
$ heroku config:set SECRET_KEY_BASE="xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53"
Setting config vars and restarting mysterious-meadow-6277... done, v3
SECRET_KEY_BASE: xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53
```

## Deploy Time!

Our project is now ready to be deployed on Heroku.

Let's commit all our changes:

```console
$ git add elixir_buildpack.config
$ git commit -a -m "Use production config from Heroku ENV variables and decrease socket timeout"
```

And deploy:

```console
$ git push heroku main
Counting objects: 55, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (49/49), done.
Writing objects: 100% (55/55), 48.48 KiB | 0 bytes/s, done.
Total 55 (delta 1), reused 0 (delta 0)
remote: Compressing source files... done.
remote: Building source:
remote:
remote: -----> Multipack app detected
remote: -----> Fetching custom git buildpack... done
remote: -----> elixir app detected
remote: -----> Checking Erlang and Elixir versions
remote:        WARNING: elixir_buildpack.config wasn't found in the app
remote:        Using default config from Elixir buildpack
remote:        Will use the following versions:
remote:        * Stack cedar-14
remote:        * Erlang 17.5
remote:        * Elixir 1.0.4
remote:        Will export the following config vars:
remote:        * Config vars DATABASE_URL
remote:        * MIX_ENV=prod
remote: -----> Stack changed, will rebuild
remote: -----> Fetching Erlang 17.5
remote: -----> Installing Erlang 17.5 (changed)
remote:
remote: -----> Fetching Elixir v1.0.4
remote: -----> Installing Elixir v1.0.4 (changed)
remote: -----> Installing Hex
remote: 2015-07-07 00:04:00 URL:https://s3.amazonaws.com/s3.hex.pm/installs/1.0.0/hex.ez [262010/262010] ->
"/app/.mix/archives/hex.ez" [1]
remote: * creating /app/.mix/archives/hex.ez
remote: -----> Installing rebar
remote: * creating /app/.mix/rebar
remote: -----> Fetching app dependencies with mix
remote: Running dependency resolution
remote: Dependency resolution completed successfully
remote: [...]
remote: -----> Compiling
remote: [...]
remote: Generated phoenix_heroku app
remote: [...]
remote: Consolidated protocols written to _build/prod/consolidated
remote: -----> Creating .profile.d with env vars
remote: -----> Fetching custom git buildpack... done
remote: -----> Phoenix app detected
remote:
remote: -----> Loading configuration and environment
remote:        Loading config...
remote:        [...]
remote:        Will export the following config vars:
remote:        * Config vars DATABASE_URL
remote:        * MIX_ENV=prod
remote:
remote: -----> Compressing... done, 82.1MB
remote: -----> Launching... done, v5
remote:        https://mysterious-meadow-6277.herokuapp.com/ deployed to Heroku
remote:
remote: Verifying deploy... done.
To https://git.heroku.com/mysterious-meadow-6277.git
 * [new branch]      master -> master
```

Typing `heroku open` in the terminal should launch a browser with the Phoenix welcome page opened. In the event that you are using Ecto to access a database, you will also need to run migrations after the first deploy:

```console
$ heroku run "POOL_SIZE=2 mix ecto.migrate"
```

And that's it!

## Deploying to Heroku using the container stack

### Create Heroku application

Set the stack of your app to `container`, this allows us to use `Dockerfile` to define our app setup.

```console
$ heroku create
Creating app... done, ⬢ mysterious-meadow-6277
$ heroku stack:set container
```

Add a new `heroku.yml` file to your root folder. In this file you can define addons used by your app, how to build the image and what configs are passed to the image. You can learn more about Heroku's `heroku.yml` options [here](https://devcenter.heroku.com/articles/build-docker-images-heroku-yml). Here is a sample:

```yaml
setup:
  addons:
    - plan: heroku-postgresql
      as: DATABASE
build:
  docker:
    web: Dockerfile
  config:
    MIX_ENV: prod
    SECRET_KEY_BASE: $SECRET_KEY_BASE
    DATABASE_URL: $DATABASE_URL
```

### Set up releases and Dockerfile

Now we need to define a `Dockerfile` at the root folder of your project that contains your application. We recommend to use releases when doing so, as the release will allow us to build a container with only the parts of Erlang and Elixir we actually use. Follow the [releases docs](releases.html). At the end of the guide, there is a sample Dockerfile file you can use.

Once you have the image definition set up, you can push your app to heroku and you can see it starts building the image and deploy it.

## Useful Heroku Commands

We can look at the logs of our application by running the following command in our project directory:

```console
$ heroku logs # use --tail if you want to tail them
```

We can also start an IEx session attached to our terminal for experimenting in our app's environment:

```console
$ heroku run "POOL_SIZE=2 iex -S mix"
```

In fact, we can run anything using the `heroku run` command, like the Ecto migration task from above:

```console
$ heroku run "POOL_SIZE=2 mix ecto.migrate"
```

## Connecting to your dyno

Heroku gives you the ability to connect to your dyno with an IEx shell which allows running Elixir code such as database queries.

- Modify the `web` process in your Procfile to run a named node:

  ```text
  web: elixir --sname server -S mix phx.server
  ```

- Redeploy to Heroku
- Connect to the dyno with `heroku ps:exec` (if you have several applications on the same repository you will need to specify the app name or the remote name with `--app APP_NAME` or `--remote REMOTE_NAME`)
- Launch an iex session with `iex --sname console --remsh server`

You have an iex session into your dyno!

## Troubleshooting

### Compilation Error

Occasionally, an application will compile locally, but not on Heroku. The compilation error on Heroku will look something like this:

```console
remote: == Compilation error on file lib/postgrex/connection.ex ==
remote: could not compile dependency :postgrex, "mix compile" failed. You can recompile this dependency with "mix deps.compile postgrex", update it with "mix deps.update postgrex" or clean it with "mix deps.clean postgrex"
remote: ** (CompileError) lib/postgrex/connection.ex:207: Postgrex.Connection.__struct__/0 is undefined, cannot expand struct Postgrex.Connection
remote:     (elixir) src/elixir_map.erl:58: :elixir_map.translate_struct/4
remote:     (stdlib) lists.erl:1353: :lists.mapfoldl/3
remote:     (stdlib) lists.erl:1354: :lists.mapfoldl/3
remote:
remote:
remote:  !     Push rejected, failed to compile elixir app
remote:
remote: Verifying deploy...
remote:
remote: !   Push rejected to mysterious-meadow-6277.
remote:
To https://git.heroku.com/mysterious-meadow-6277.git
```

This has to do with stale dependencies which are not getting recompiled properly. It's possible to force Heroku to recompile all dependencies on each deploy, which should fix this problem. The way to do it is to add a new file called `elixir_buildpack.config` at the root of the application. The file should contain this line:

```text
always_rebuild=true
```

Commit this file to the repository and try to push again to Heroku.

### Connection Timeout Error

If you are constantly getting connection timeouts while running `heroku run` this could mean that your internet provider has blocked port number 5000:

```console
heroku run "POOL_SIZE=2 mix myapp.task"
Running POOL_SIZE=2 mix myapp.task on mysterious-meadow-6277... !
ETIMEDOUT: connect ETIMEDOUT 50.19.103.36:5000
```

You can overcome this by adding `detached` option to run command:

```console
heroku run:detached "POOL_SIZE=2 mix ecto.migrate"
Running POOL_SIZE=2 mix ecto.migrate on mysterious-meadow-6277... done, run.8089 (Free)
```
