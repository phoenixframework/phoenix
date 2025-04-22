# Deploying on Gigalixir

Our main goal for this guide is to get a Phoenix application running on Gigalixir.

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](https://hexdocs.pm/phoenix/up_and_running.html).

## Steps

Let's separate this process into a few steps, so we can keep track of where we are.

- Initialize Git repository
- Install the Gigalixir CLI
- Sign up for Gigalixir
- Create and set up Gigalixir application
- Provision a database
- Make our project ready for Gigalixir
- Deploy time!
- Useful Gigalixir commands

## Initializing Git repository

If you haven't already, we'll need to commit our files to git. We can do so by running the following commands in our project directory:

```console
$ git init
$ git add .
$ git commit -m "Initial commit"
```

## Installing the Gigalixir CLI

Follow the instructions [here](https://gigalixir.com/docs/getting-started-guide/) to install the command-line interface for your platform.

## Signing up for Gigalixir

We can sign up for an account at [gigalixir.com](https://gigalixir.com) or with the CLI. Let's use the CLI.

```console
$ gigalixir signup

# or with a Google account
$ gigalixir signup:google
```

Gigalixir’s free tier does not require a credit card and comes with 1 app instance and 1 PostgreSQL database for free, but please consider upgrading to a paid plan if you are running a production application.

Next, let's login

```console
$ gigalixir login

# or with a Google account
$ gigalixir login:google
```

And verify

```console
$ gigalixir account
```

## Creating and setting up our Gigalixir application

There are two different ways to deploy a Phoenix app on Gigalixir: with mix or with Elixir's releases. In this guide, we'll be using Elixir's releases because it is the recommended way. For more information, see [Elixir Releases vs Mix](https://gigalixir.com/docs/modify-app/#elixir-releases-vs-mix). If you want to deploy with the mix method, follow the [Phoenix deploy with Mix Guide](https://gigalixir.com/docs/getting-started-guide/phoenix-mix-deploy).

### Creating a Gigalixir application

Let's create a Gigalixir application

```console
$ gigalixir create -n "your-app-name"
```

Note: the app name cannot be changed afterwards. A random name is used if you do not provide one.

### Specifying versions

Gigalixir requires that you specify the Erlang and Elixir versions you intend to use. It's generally a good idea to run the same version in production as you do in development. For example:

```console
$ echo 'elixir_version=1.17.2' > elixir_buildpack.config
$ echo 'erlang_version=27.0' >> elixir_buildpack.config
$ git add elixir_buildpack.config
```

Gigalixir will use the latest nodejs version if you do not specify a version. If you want to specify your nodejs version, you can do so like this:

```console
$ echo 'node_version=22.7.0' > phoenix_static_buildpack.config
$ git add elixir_buildpack.config phoenix_static_buildpack.config assets/package.json
```

Finally, don't forget to commit:

```console
$ git commit -m "Set versions"
```

## Provisioning a database

Let's provision a database for our app. For a free database, run the following command

```console
$ gigalixir pg:create --free
```

For a production ready database, be sure to upgrade your account to the Standard Tier and create a Standard tier database
```console
$ gigalixir account:upgrade
$ gigalixir pg:create
```

Verify the database was created

```console
$ gigalixir pg
```

Verify that a `DATABASE_URL` and `POOL_SIZE` were created

```console
$ gigalixir config
```

## Making our Project ready for Gigalixir

There's nothing we need to do to get our app running on Gigalixir, but for a production app, you probably want to enforce SSL.

### Database Connection Security

You may also want to use SSL for your database connection. In your `config/runtime.exs`:

```elixir
ssl: [
  verify: :verify_peer,
  cacerts: :public_key.cacerts_get()
]
```

## Deploy Time!

Our project is now ready to be deployed on Gigalixir.
Be sure you have everything committed to git and run the following command:

```console
$ git push gigalixir
```

Check the status of your deploy and wait until the app is `Healthy`

```console
$ gigalixir ps
```

Run migrations

```console
$ gigalixir ps:migrate
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

To set up clustering, see [Clustering Nodes](https://gigalixir.com/docs/cluster)

For custom domains, scaling, jobs and other features, see the [Gigalixir Documentation](https://gigalixir.com/docs/).

## Troubleshooting

See [Troubleshooting](https://gigalixir.com/docs/troubleshooting) and the [FAQ](https://gigalixir.com/docs/faq)

Also, don't hesitate to email [help@gigalixir.com](mailto:help@gigalixir.com) or [request an invitation](https://elixir-lang.slack.com/join/shared_invite/zt-1f13hz7mb-N4KGjF523ONLCcHfb8jYgA#/shared-invite/email) and join the #gigalixir channel on [Slack](https://elixir-lang.slack.com).
