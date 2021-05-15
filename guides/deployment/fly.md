# Deploying on Fly

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](up_and_running.html).

## Goals

Our main goal for this guide is to get a Phoenix application running on Fly.io.

## Steps

Let's separate this process into a few steps so we can keep track of where we are.

- Install the Fly CLI
- Sign up for Fly
- Make our project ready for Fly
- Create and set up our Fly application
- Provision a database
- Deploy time!
- Helpful Fly resources

## Installing the Fly CLI

Follow the instructions [here](https://fly.io/docs/getting-started/installing-flyctl/) to install the command-line interface for the Fly platform.

## Sign up for Fly

We can [sign up for an account](https://fly.io/docs/getting-started/login-to-fly/) using the CLI.

```console
$ fly auth signup
```

Fly has a [free tier](https://fly.io/docs/about/pricing/) for applications without a database. A credit card is required when setting up an account to help prevent abuse. See the [pricing](https://fly.io/docs/about/pricing/) page for more details.

## Make our project ready for Fly

For this guide, we'll use a Dockerfile and build a release for our Fly deployment. Internally, Fly's networking uses IPv6, so there is a little config we can do to our application to make it a smooth experience.

### Use releases

Configure the application to [Deploy using Releases](releases.html) including the section on Containers. There is a guide for deploying Elixir applications in the [Fly documentation](https://fly.io/docs/getting-started/elixir/) that you can refer to for this as well.

### Runtime configuration

After following the [Deploy using Releases](releases.html) steps with the `config/runtime.exs` file, we are ready to configure it for Fly.

Update the `config/runtime.exs` file to follow this example:

```elixir
import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  app_name =
    System.get_env("FLY_APP_NAME") ||
      raise "FLY_APP_NAME not available"

  config :my_app, MyAppWeb.Endpoint,
    server: true,
    url: [host: "#{app_name}.fly.dev", port: 80],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :my_app, MyApp.Repo,
    url: database_url,
    # IMPORTANT: Or it won't find the DB server
    socket_options: [:inet6],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
```

The areas to pay attention to are:

* Using `FLY_APP_NAME` for the host in the Endpoint
* Using an IPv6 binding on the Endpoint
* Using `:inet6` for the Repo's socket options

Also, you don't need to turn on TLS for connecting to the PostgreSQL instance. Fly private networks operate over an encrypted WireGuard mesh, so traffic between application servers and PostgreSQL is already encrypted and there's no need to TLS.

### Generate release config files

We use the `mix release.init` command to create some sample files in the `./rel` directory.

```console
$ mix release.init
```

We only need to configure `rel/env.sh.eex`. This file is used when running any of the release commands. Here are the important parts.

```
#!/bin/sh

ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=$FLY_APP_NAME@$ip
export ELIXIR_ERL_OPTIONS="-proto_dist inet6_tcp"
```

We configure the node to use a full node name when it runs. We get the Fly assigned IPv6 address and use that with the `$FLY_APP_NAME` to name the node. Finally, we configure `inet6_tcp` for the BEAM as well.

## Create and set up our Fly application

To tell Fly about your application, run `fly launch` in the directory with your source code. This creates and configures a fly app.

```console
$ fly launch
```

After your source code is scanned and the results are printed, you'll be prompted for an organization. Organizations are a way of sharing applications and resources between Fly users. Every Fly account has a personal organization, called `personal`, which is only visible to your account. Let's select that for this guide.

Next, you'll be prompted to select a region to deploy in. The closest region to you is selected by default. You can use this or change to another region. You can find the [list of supported regions here](https://fly.io/docs/reference/regions/).

At this point, `flyctl` creates a Fly-side application slot with a new name and wrote your configuration to a `fly.toml` file. You'll then be prompted to build and deploy your app. Don't deploy it just yet. We're going to adjust the generated `fly.toml` file first.

### Customizing `fly.toml`

The `fly.toml` file contains a default configuration for deploying your app. If you don't provide a name to use, a name will be generated for you.

The following is an example of a customized `fly.toml` file.

```toml
app = "your-app-name-here"

kill_signal = "SIGTERM"
kill_timeout = 5

[env]

[deploy]
  release_command = "/app/bin/my_app eval MyApp.Release.migrate"

[[services]]
  internal_port = 4000
  protocol = "tcp"

  [services.concurrency]
    hard_limit = 25
    soft_limit = 20

  [[services.ports]]
    handlers = ["http"]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

  [[services.tcp_checks]]
    grace_period = "30s" # allow some time for startup
    interval = "15s"
    restart_limit = 6
    timeout = "2s"
```

There are two important changes here:

- We added the `[deploy]` setting. This tells Fly that on a new deploy, **run our database migrations**. The text here depends on your application name. This is calling a module you created when updating your application for deploying with releases.
- The `kill_signal` is set to `SIGTERM`. An Elixir node does a clean shutdown when it receives a `SIGTERM` from the OS.

Some other values were tweaked as well. Check that `internal_port` matches the port for your application.

### Storing secrets on Fly

Before we deploy our new app, we first want to setup a few things in our Fly account. Any secrets that we don't want compiled into the source code are stored externally. An example of that is our Phoenix key base secret.

Elixir has a mix task that generates a new Phoenix key base secret. Let's use that.

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
```

It generates a long string of random text. Let's store that with Fly as a secret for our app. When we run this command in our project folder, `flyctl` uses the `fly.toml` file to know which app we are setting the value on.

```console
$ fly secrets set SECRET_KEY_BASE=REALLY_LONG_SECRET
```

## Provision a database

Most Elixir applications use a database and PostgreSQL is the default one used. Let's provision a database on Fly for our application.

```console
$ fly postgres create
```

When naming the database, you can use something like `my-app-db`. Taking the defaults gives you a small database to start playing with.

Now we need to "attach" the database to our application.

```console
$ fly postgres attach --postgres-app my-app-db
```

When the database is attached, it creates the secrets needed by your application. You can see what secrets were created this way.

```console
$ fly secrets list
```

With our application configured for releases, a Dockerfile defined for packaging it, our `config/runtime.exs` and `rel/env.sh.eex` files configured, a Fly app defined, our secrets stored in Fly, and a database provisioned, we are ready to deploy!

## Deploy time!

Our project is now ready to be deployed to Fly.io.

```console
$ fly deploy
```

You can always check on the status of a deploy

```console
$ fly status
```

Check your app logs

```console
$ fly logs
```

If everything looks good, open your app on Fly

```console
$ fly open
```

### Getting an IEx shell into a running node

Elixir supports getting a IEx shell into a running production node. We already took the steps to configure `rel/env.sh.eex`, so this step should be pretty easy.

There are a couple prerequisites, we first need to establish an [SSH Shell](https://fly.io/docs/flyctl/ssh/) to our machine on Fly.

This step sets up a root certificate for your account and then issues a certificate.

```console
$ fly ssh establish
$ fly ssh issue
```

With SSH configured, let's open a console.

```console
$ fly ssh console
Connecting to my-app-1234.internal... complete
/ #
```

If all has gone smoothly, then you have a shell into the machine! Now we just need to launch our remote IEx shell. The deployment Dockerfile was configured to pull our application into `/app`. So our command for the `my_app` app looks like this:

```console
$ app/bin/my_app remote
Erlang/OTP 23 [erts-11.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1]

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(my_app@fdaa:0:1da8:a7b:ac4:b204:7e29:2)1>
```

Now we have a running IEx shell into our node. You can safely disconnect using CTRL+C, CTRL+C.

## Clustering your application

Elixir and the BEAM have the incredible ability to be clustered together and pass messages seamlessly between nodes. This portion of the guide walks you through clustering your Elixir application.

There are 2 parts to getting clustering quickly setup on Fly.

- Installing and using `libcluster`
- Scaling the application to multiple instances

### Adding `libcluster`

The widely adopted library [libcluster](https://github.com/bitwalker/libcluster) helps here.

There are multiple strategies that `libcluster` can use to find and connect with other nodes. The strategy we'll use on Fly is `DNSPoll`.

After installing `libcluster`, add it to the application like this:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # ...
      # setup for clustering
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}
    ]

    # ...
  end

  # ...
end
```

Our next step is to add the `topologies` configuration to `config/runtime.exs`.

```elixir
  app_name =
    System.get_env("FLY_APP_NAME") ||
      raise "FLY_APP_NAME not available"

  config :libcluster,
    topologies: [
      fly6pn: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          polling_interval: 5_000,
          query: "#{app_name}.internal",
          node_basename: app_name
        ]
      ]
    ]
```

This configures `libcluster` to use the `DNSPoll` strategy and look for other deployed apps using the `$FLY_APP_NAME` on the `.internal` private network.

This assumes that your `rel/env.sh.eex` file is configured to name your Elixir node using the `$FLY_APP_NAME`.

Before it can be clustered, we have to have multiple instances. Next we'll add an additional node instance.

### Running multiple instances

There are two ways to run multiple instances.

1. Scale our application to have multiple instances in one region.
2. Add an instance to another region (multiple regions).

Let's first start with a baseline of our single deployment.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
f9014bf7 26      sea    run     running 1 total, 1 passing 0        1h8m ago
```

### Scaling in a single region

Let's scale up to 2 instances in our current region.

```console
$ fly scale count 2
Count changed to 2
```

Checking the status we can see what happened.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
eb4119d3 27      sea    run     running 1 total, 1 passing 0        39s ago
f9014bf7 27      sea    run     running 1 total, 1 passing 0        1h13m ago
```

We now have two instances in the same region.

Let's make sure they are clustered together. We can check the logs:

```console
$ fly logs
...
app[eb4119d3] sea [info] 21:50:21.924 [info] [libcluster:fly6pn] connected to :"my-app-1234@fdaa:0:1da8:a7b:ac2:f901:4bf7:2"
...
```

But that's not as rewarding as seeing it from inside a node. From an IEx shell, we can ask the node we're connected to, what other nodes it can see.

```console
$ fly ssh console
$ /app/bin/my_app remote
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:f901:4bf7:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ac4:eb41:19d3:2"]
```

The IEx prompt is included to help show the IP address of the node we are connected to. Then getting the `Node.list` returns the other node. Our two instances are connected and clustered!

### Scaling to multiple regions

Fly makes it easy to deploy instances closer to your users. Through the magic of DNS, users are directed to the nearest region where your application is located. You can read more about [Fly regions here](https://fly.io/docs/reference/regions/).

Starting back from our baseline of a single instance running in `sea` which is Seattle, Washington (US), Let's add the region `ewr` which is Parsippany, NJ (US). This puts an instance on both coasts of the US.

```console
$ fly regions add ewr
Region Pool:
ewr
sea
Backup Region:
iad
lax
sjc
vin
```

Looking at the status shows that we're only in 1 region because our count is set to 1.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
cdf6c422 29      sea    run     running 1 total, 1 passing 0        58s ago
```

Let's add a 2nd instance and see it deploy to `ewr`.

```console
$ fly scale count 2
Count changed to 2
```

Now the status shows we have two instances spread across 2 regions!

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
0a8e6666 30      ewr    run     running 1 total, 1 passing 0        16s ago
cdf6c422 30      sea    run     running 1 total, 1 passing 0        6m47s ago
```

Let's ensure they are clustered together.

```console
$ fly ssh console
$ /app/bin/my_app remote
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:cdf6:c422:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ab2:a8e:6666:2"]
```

We have two instances of our application deployed to the West and East coasts of the North American continent and they are clustered together! Our users will automatically be directed to the server nearest them.

The Fly platform has built-in distribution support making it easy to cluster distributed Elixir nodes in multiple regions.

## Helpful Fly commands and resources

Open the Dashboard for your account

```console
$ fly dashboard
```

Deploy your application

```console
$ fly deploy
```

Show the status of your deployed application

```console
$ fly status
```

Access and tail the logs

```console
$ fly logs
```

Scaling your application up or down

```console
$ fly scale count 2
```

Refer to the [Fly Elixir documentation](https://fly.io/docs/getting-started/elixir) for additional information.

[Working with Fly applications](https://fly.io/docs/getting-started/working-with-fly-apps/) covers things like:

* Status and logs
* Custom domains
* Certificates

## Troubleshooting

See [Troubleshooting](https://fly.io/docs/getting-started/troubleshooting/#welcome-message)

Visit the [Fly Community](https://community.fly.io/) to find solutions and ask questions.