# Deploying on Heroku

### What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](http://www.phoenixframework.org/docs/up-and-running).

### Goals

Our main goal for this guide is to get a Phoenix application running on Heroku.

### Limitations

Heroku is a great platform and Elixir performs well on it. However, you may run into limitations if you plan to leverage advanced features provided by Elixir and Phoenix, such as:

- Connections are limited.
    - Heroku [limits the number of simultaneous connections](https://devcenter.heroku.com/articles/http-routing#request-concurrency) as well as the [duration of each connection](https://devcenter.heroku.com/articles/limits#http-timeouts). It is common to use Elixir for real-time apps which need lots of concurrent, persistent connections, and Phoenix is capable of [handling over 2 million connections on a single server](http://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections).

- Distributed clustering is not possible.
    - Heroku [firewalls dynos off from one another](https://devcenter.heroku.com/articles/dynos#networking). This means things like [distributed Phoenix channels](https://dockyard.com/blog/2016/01/28/running-elixir-and-phoenix-projects-on-a-cluster-of-nodes) and [distributed tasks](https://elixir-lang.org/getting-started/mix-otp/distributed-tasks-and-configuration.html) will need to rely on something like Redis instead of Elixir's built-in distribution.

- In-memory state such as those in [Agents](https://elixir-lang.org/getting-started/mix-otp/agent.html), [GenServers](https://elixir-lang.org/getting-started/mix-otp/genserver.html), and [ETS](https://elixir-lang.org/getting-started/mix-otp/ets.html) will be lost every 24 hours.
    - Heroku [restarts dynos](https://devcenter.heroku.com/articles/dynos#restarting) every 24 hours regardless of whether the node is healthy.

- [Remote shells](https://hexdocs.pm/iex/IEx.html#module-remote-shells) and remote observer are not possible.
    - Heroku does not allow SSH access to your dynos so you can not inspect, debug, or trace your production nodes using things like [the built-in Observer](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html#observer).

If you are just getting started or you don't expect to use the features above, Heroku should be enough for your needs. For instance, if you are migrating an existing application running on Heroku to Phoenix, keeping a similar set of features, Elixir will perform just as well or even better then your current stack.

If you want a platform-as-a-service without these limitations, try [Gigalixir](http://gigalixir.readthedocs.io/). If you would rather deploy to a cloud platform, such as EC2, Google Cloud, etc, consider [Distillery](https://github.com/bitwalker/distillery).

## Steps

Let's separate this process into a few steps so we can keep track of where we are.

- Initialize Git repository
- Sign up for Heroku
- Install the Heroku Toolbelt
- Create the Heroku application
- Add the Phoenix static buildpack
- Make our project ready for Heroku
- Deploy time!
- Useful Heroku commands

## Initializing Git repository

[Git](https://git-scm.com/) is a popular decentralized revision control system and is also used to deploy apps to Heroku.

Before we can push to Heroku we'll need to initialize a local Git repository and commit our files to it. We can do so by running the following commands in our project directory:

```console
$ git init
$ git add .
$ git commit -m "Initial commit"
```

Heroku offers some great information on how it is using Git [here](https://devcenter.heroku.com/articles/git#tracking-your-app-in-git).

## Signing up for Heroku

Signing up to Heroku is very simple, just head over to [https://signup.heroku.com/](https://signup.heroku.com/) and fill in the form.

The Free plan will give us one web [dyno](https://devcenter.heroku.com/articles/dynos#dynos) and one worker dyno, as well as a PostgreSQL and Redis instance for free.

These are meant to be used for testing and development, and come with some limitations. In order to run a production application, please consider upgrading to a paid plan.

## Installing the Heroku Toolbelt

Once we have signed up, we can download the correct version of the Heroku Toolbelt for our system [here](https://toolbelt.heroku.com/).

The Heroku CLI, part of the Toolbelt, is useful to create Heroku applications, list currently running dynos for an existing application, tail logs or run one-off commands (mix tasks for instance).

## Creating the Heroku Application

Now that we have the Toolbelt installed, let's create the Heroku application. In our project directory, run:

> Note: the first time we use a Heroku command, it may prompt us to log in. If this happens, just enter the email and password you specified during signup.

```console
$ heroku create --buildpack "https://github.com/HashNuke/heroku-buildpack-elixir.git"
Creating mysterious-meadow-6277... done, stack is cedar-14
Buildpack set. Next release on mysterious-meadow-6277 will use https://github.com/HashNuke/heroku-buildpack-elixir.git.
https://mysterious-meadow-6277.herokuapp.com/ | https://git.heroku.com/mysterious-meadow-6277.git
Git remote heroku added
```

> Note: the name of the Heroku application is the random string after "Creating" in the output above (mysterious-meadow-6277). This will be unique, so expect to see a different name from "mysterious-meadow-6277".

The `--buildpack` option we are passing allows us to specify the [Elixir buildpack](https://github.com/HashNuke/heroku-buildpack-elixir) we want Heroku to use.
A [buildpack](https://devcenter.heroku.com/articles/buildpacks) is a convenient way of packaging framework and/or runtime support. In our case it's installing Erlang, Elixir, fetching our application dependencies, and so on, before we run it.

The URL in the output is the URL to our application. If we open it in our browser now, we will get the default Heroku welcome page.

> Note: if we hadn't initialized our Git repository before we ran the `heroku create` command, we wouldn't have our Heroku remote repository properly set up at this point. We can set that up manually by running: `heroku git:remote -a [our-app-name].`

## Adding the Phoenix Static Buildpack

We need to compile static assets for a successful Phoenix deployment. The [Phoenix static buildpack](https://github.com/gjaldon/heroku-buildpack-phoenix-static) can take care of that for us, so let's add it now.

_Skip this step if you do not have any static assets (i.e. you created your project with the `--no-brunch --no-html` flags)._

```console
$ heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Buildpack added. Next release on mysterious-meadow-6277 will use:
  1. https://github.com/HashNuke/heroku-buildpack-elixir.git
  2. https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Run `git push heroku master` to create a new release using these buildpacks.
```

## Making our Project ready for Heroku

Every new Phoenix project ships with a config file `config/prod.secret.exs` which stores configuration that should not be committed along with our source code. By default Phoenix adds it to our `.gitignore` file.

This works great except Heroku uses [environment variables](https://devcenter.heroku.com/articles/config-vars) to pass sensitive informations to our application. It means we need to make some changes to our config before we can deploy.

First, let's make sure our secret key is loaded from Heroku's environment variables instead of `config/prod.secret.exs` by adding a `secret_key_base` line  in `config/prod.exs` (remember to add a comma to the end of the preceding line):

```elixir
config :hello, HelloWeb.Endpoint,
  load_from_system_env: true,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE")
```

Then, we'll add the production database configuration to `config/prod.exs`:

```elixir
# Configure your database
config :hello, Hello.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true
```

Now, let's tell Phoenix to use our Heroku URL and enforce we only use the SSL version of the website. Find the url line:

```elixir
url: [host: "example.com", port: 80],
```

... and replace it with this (don't forget to replace `mysterious-meadow-6277` with your application name):

```elixir
url: [scheme: "https", host: "mysterious-meadow-6277.herokuapp.com", port: 443],
force_ssl: [rewrite_on: [:x_forwarded_proto]],
```

Since our configuration is now handled using Heroku's environment variables, we don't need to import the `config/prod.secret.exs` file in `/config/prod.exs` any longer, so we can delete the following line:

```elixir
import_config "prod.secret.exs"
```

Our `config/prod.exs` now looks like this:

```elixir
use Mix.Config

...

config :hello, HelloWeb.Endpoint,
  load_from_system_env: true,
  url: [scheme: "https", host: "mysterious-meadow-6277.herokuapp.com", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE")

# Do not print debug messages in production
config :logger, level: :info

# Configure your database
config :hello, Hello.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true
```

Finally, we need to decrease the timeout for the websocket transport in `lib/hello_web/channels/user_socket.ex`:

```elixir
defmodule HelloWeb.UserSocket do
  use Phoenix.Socket

  ...

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket,
    timeout: 45_000
    ...
end
```

This ensures that any idle connections are closed by Phoenix before they reach Heroku's 55-second timeout window.

Lastly, we'll need to create a [Procfile](https://devcenter.heroku.com/articles/procfile) (a text file called "Procfile" in the root of our project’s folder) with the following line:

```
web: MIX_ENV=prod mix phx.server
```

## Creating Environment Variables in Heroku

The `DATABASE_URL` config var is automatically created by Heroku when we add the [Heroku Postgres add-on](https://elements.heroku.com/addons/heroku-postgresql). We can create the database via the heroku toolbelt:

```console
$ heroku addons:create heroku-postgresql:hobby-dev
```

Now we set the `POOL_SIZE` config var:

```console
$ heroku config:set POOL_SIZE=18
```

This value should be just under the number of available connections, leaving a couple open for migrations and mix tasks. The hobby-dev database allows 20 connections, so we set this number to 18. If additional dynos will share the database, reduce the `POOL_SIZE` to give each dyno an equal share.

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

If you need to make any of your config variables available at compile time, you will need to explicitly define which ones in a configuration file. Create a file `elixir_buildpack.config` in your application's root directory and add a line like: `config_vars_to_export=(MY_VAR)`. See [here](https://github.com/HashNuke/heroku-buildpack-elixir#specifying-config-vars-to-export-at-compile-time) for more information.

## Deploy Time!

Our project is now ready to be deployed on Heroku.

Let's commit all our changes:

```
$ git add config/prod.exs
$ git add Procfile
$ git add lib/hello_web/channels/user_socket.ex
$ git commit -m "Use production config from Heroku ENV variables and decrease socket timeout"
```

And deploy:

```console
$ git push heroku master
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
remote:        WARNING: phoenix_static_buildpack.config wasn't found in the app
remote:        Using default config from Phoenix static buildpack
remote:        Will use the following versions:
remote:        * Node 0.12.4
remote:        Will export the following config vars:
remote:        * Config vars DATABASE_URL
remote:        * MIX_ENV=prod
remote:
remote: -----> Installing binaries
remote:        Downloading node 0.12.4...
remote:        Installing node 0.12.4...
remote:        Using default npm version
remote:
remote: -----> Building dependencies
remote:        [...]
remote:        Running default compile
remote:               Building Phoenix static assets
remote:        07 Jul 00:06:22 - info: compiled 3 files into 2 files, copied 3 in 3616ms
remote:        Check your digested files at 'priv/static'.
remote:
remote: -----> Finalizing build
remote:        Creating runtime environment
remote:
remote: -----> Discovering process types
remote:        Procfile declares types     -> (web)
remote:        Default types for Multipack -> web
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

```
always_rebuild=true
```

Commit this file to the repository and try to push again to Heroku.

### Connection Timeout Error

If you are constantly getting connection timeouts while running `heroku run` this could mean that your internet provider has blocked
port number 5000:

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
