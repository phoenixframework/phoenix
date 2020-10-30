# Deploying on Gigalixir

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](https://hexdocs.pm/phoenix/up_and_running.html).

## Goals

Our main goal for this guide is to get a Phoenix application running on Gigalixir.

## Steps

Let's separate this process into a few steps so we can keep track of where we are.

- Initialize Git repository
- Install the Gigalixir CLI
- Sign up for Gigalixir
- Create and set up Gigalixir application
- Provision a database
- Make our project ready for Gigalixir
- Deploy time!
- Useful Gigalixir commands

## Initializing Git repository

If you haven't already, we'll need to commit our files git. We can do so by running the following commands in our project directory:

```console
$ git init
$ git add .
$ git commit -m "Initial commit"
```

## Installing the Gigalixir CLI

Follow the instructions [here](https://gigalixir.readthedocs.io/en/latest/getting-started-guide.html#install-the-command-line-interface) to install the command-line interface for your platform.

## Signing up for Gigalixir

We can sign up for an account at [gigalixir.com](https://www.gigalixir.com) or with the CLI. Let's use the CLI.

```console
$ gigalixir signup
```

Gigalixir’s free tier does not require a credit card and comes with 1 app instance and 1 postgresql database for free, but please consider upgrading to a paid plan if you are running a production application.

Next, let's login

```console
$ gigalixir login
```

And verify

```console
$ gigalixir account
```

## Creating and setting up our Gigalixir application

There are three different ways to deploy a Phoenix app on Gigalixir: with mix, with Elixir's releases, or with Distillery. In this guide, we'll be using Mix because it is the easiest to get up and running, but you won't be able to connect a remote observer or hot upgrade. For more information, see [Mix vs Distillery vs Elixir Releases](https://gigalixir.readthedocs.io/en/latest/modify-app/index.html#mix-vs-distillery-vs-elixir-releases). If you want to deploy with another method, follow the [Getting Started Guide](https://gigalixir.readthedocs.io/en/latest/getting-started-guide.html).

### Creating a Gigalixir application

Let's create a Gigalixir application

```console
$ gigalixir create
```

Verify it was created

```console
$ gigalixir apps
```

Verify that a git remote was created 

```console
$ git remote -v
```

### Specifying versions

The buildpacks we use default to Elixir, Erlang, and Nodejs versions that are quite old and it's generally a good idea to run the same version in production as you do in development, so let's do that.

```console
$ echo "elixir_version=1.10.3" > elixir_buildpack.config
$ echo "erlang_version=22.3" >> elixir_buildpack.config
$ echo "node_version=12.16.3" > phoenix_static_buildpack.config
```

Don't forget to commit

```console
$ git add elixir_buildpack.config phoenix_static_buildpack.config
$ git commit -m "set elixir, erlang, and node version"
```
## Making our Project ready for Gigalixir

There's nothing we need to do to get our app running on Giglaixir, but for a production app, you probably want to enforce SSL. To do that, see [Force SSL](https://hexdocs.pm/phoenix/using_ssl.html#force-ssl)

You may also want to use SSL for your database connection. For that, uncomment the line `ssl: true` in your `Repo` config.

## Provisioning a database

Let's provision a database for our app

```console
$ gigalixir pg:create --free
```

Verify the database was created

```console
$ gigalixir pg
```

Verify that a `DATABASE_URL` and `POOL_SIZE` were created

```console
$ gigalixir config
```

## Deploy Time!

Our project is now ready to be deployed on Gigalixir.

```console
$ git push gigalixir
```

Check the status of your deploy and wait until the app is `Healthy`

```console
$ gigalixir ps
```

Run migrations

```console
$ gigalixir run mix ecto.migrate
```

Check your app logs

```console
$ gigalixir logs
```

If everything looks good, let's take a look at your app running on Gigalixir

```console
$ gigalixir open
```

## Useful Gigalixir Commands

Open a remote console

```console
$ gigalixir account:ssh_keys:add "$(cat ~/.ssh/id_rsa.pub)"
$ gigalixir ps:remote_console
```

To open a remote observer, see [Remote Observer](https://gigalixir.readthedocs.io/en/latest/runtime.html#how-to-launch-a-remote-observer)

To set up clustering, see [Clustering Nodes](https://gigalixir.readthedocs.io/en/latest/cluster.html)

To hot upgrade, see [Hot Upgrades](https://gigalixir.readthedocs.io/en/latest/deploy.html#how-to-hot-upgrade-an-app)

For custom domains, scaling, jobs and other features, see the [Gigalixir Documentation](https://gigalixir.readthedocs.io/)

## Troubleshooting

See [Troubleshooting](https://gigalixir.readthedocs.io/en/latest/troubleshooting.html)

Also, don't hesitate to email [help@gigalixir.com](mailto:help@gigalixir.com) or [request an invitation](https://elixir-slackin.herokuapp.com/) and join the #gigalixir channel on [Slack](https://elixir-lang.slack.com).
