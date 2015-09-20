### What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](http://www.phoenixframework.org/docs/up-and-running).

### Goals

Our main goal for this guide is to get a Phoenix application running on Heroku.

## Steps

Let's separate this process into a few steps so we can keep track of where we are.

- Initialize Git repository
- Sign up for Heroku
- Install the Heroku Toolbelt
- Create the Heroku application
- Add the Phoenix static buildpack
- Make our project Heroku-ready
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

Signing up to Heroku is very simple, just head over to [https://signup.heroku.com/www-header](https://signup.heroku.com/www-header) and fill in the form.

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

> Note: if we hadn't initialized our Git repository before we ran the `heroku create` command, we won't have our Heroku remote repository properly set up at this point. We can set that up manually by running: `heroku git:remote -a [our-app-name].`

## Adding the Phoenix Static Buildpack

We need to compile static assets for a successful Phoenix deployment. The [Phoenix static buildpack](https://github.com/gjaldon/heroku-buildpack-phoenix-static) can take care of that for us, so let's add it now.

```console
$ heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Buildpack added. Next release on mysterious-meadow-6277 will use:
  1. https://github.com/HashNuke/heroku-buildpack-elixir.git
  2. https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Run `git push heroku master` to create a new release using these buildpacks.
```

## Making our Project Heroku-ready

Every new Phoenix project ships with a config file `config/prod.secret.exs` which stores configuration that should not be commited along with our source code. By default Phoenix adds it to our `.gitignore` file.

This works great except Heroku uses [environment variables](https://devcenter.heroku.com/articles/config-vars) to pass sensitive informations to our application. It means we need to make some changes to our config before we can deploy.

First, let's copy over the content of `config/prod.secret.exs` to `config/prod.exs`.

Now we need to load the necessary environment variables in our configuration.

In our case:

```elixir
config :hello_phoenix, HelloPhoenix.Endpoint,
  secret_key_base: "my_secret_key"
```

becomes:

```elixir
config :hello_phoenix, HelloPhoenix.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
```

and:

```elixir
config :hello_phoenix, HelloPhoenix.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "hello_phoenix_prod",
  pool_size: 20
```

becomes:

```elixir
config :hello_phoenix, HelloPhoenix.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: 20
```

Finally, let's tell Phoenix to use our Heroku URL and enforce we only use the SSL version of the website. Find the following:

```elixir
url: [host: "example.com", port: 80],
```

and change it to (you will want to set your Heroku application name):

```elixir
url: [scheme: "https", host: "mysterious-meadow-6277.heroku.com", port: 443],
force_ssl: [rewrite_on: [:x_forwarded_proto]],
```

We don't need to import the `config/prod.secret.exs` file in our prod config any longer so we can delete the following line:

```elixir
import_config "prod.secret.exs"
```

The final `config/prod.exs` should now look something like this (we've removed the comments for readability):

```elixir
use Mix.Config

config :hello_phoenix, HelloPhoenix.Endpoint,
  http: [port: System.get_env("PORT")],
  url: [scheme: "https", host: "mysterious-meadow-6277.heroku.com", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/manifest.json"

config :logger, level: :info

config :hello_phoenix, HelloPhoenix.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :hello_phoenix, HelloPhoenix.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: 20
```

## Creating Environment Variables in Heroku

The `DATABASE_URL` config var is automatically created by Heroku when we add the [Heroku Postgres add-on](https://addons.heroku.com/heroku-postgresql).

We still have to create the `SECRET_KEY_BASE` config based on a random string. First, use `mix phoenix.gen.secret` to get a new secret:

```console
$ mix phoenix.gen.secret
A_LONG_STRING_WILL_BE_PRINTED
```

Now set it in Heroku:

```console
$ heroku config:set SECRET_KEY_BASE="A_LONG_STRING_WILL_BE_PRINTED"
Setting config vars and restarting mysterious-meadow-6277... done, v3
SECRET_KEY_BASE: my_secret_key_base
```

## Deploy Time!

Our project is now ready to be deployed on Heroku.

Let's commit all our changes:

```
$ git add config/prod.exs .gitignore
$ git commit -m "Heroku ready"
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
remote:        Procfile declares types     -> (none)
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

Typing `heroku open` in the terminal should launch a browser with the Phoenix welcome page opened. In case you are using Ecto to access a database, you will also need to run migrations after the first deploy:

```console
$ heroku run mix ecto.migrate
```

And that's it!

## Useful Heroku Commands

We can look at the logs of our application by running the following command in our project directory:

```console
$ heroku logs # use --tail if you want to tail them
```

We can also start an IEx session attached to our terminal for experimenting in our app's environment:

```console
$ heroku run iex -S mix
```

In fact, we can run anything using the `heroku run` command, like the Ecto migration task from above:

```console
$ heroku run mix ecto.migrate
```
