# Deploying on Fly.io


Fly.io maintains their own guide for Elixir/Phoenix here: [Fly.io/docs/elixir/getting-started/](https://fly.io/docs/elixir/getting-started/) we will keep this guide up but for the latest and greatest check with them!

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](https://hexdocs.pm/phoenix/up_and_running.html).

You can just:

```console
$ mix phx.new my_app
```

## Goals

The main goal for this guide is to get a Phoenix application running on [Fly.io](https://fly.io).

## Sections

Let's separate this process into a few steps, so we can keep track of where we are.

- Install the Fly.io CLI
- Sign up for Fly.io
- Deploy the app to Fly.io
- Extra Fly.io tips
- Helpful Fly.io resources

## Installing the Fly.io CLI

Follow the instructions [here](https://fly.io/docs/getting-started/installing-flyctl/) to install Flyctl, the command-line interface for the Fly.io platform.

## Sign up for Fly.io

We can [sign up for an account](https://fly.io/docs/getting-started/log-in-to-fly/) using the CLI.

```console
$ fly auth signup
```

Or sign in.

```console
$ flyctl auth login
```

Fly has a [free tier](https://fly.io/docs/about/pricing/) for most applications. A credit card is required when setting up an account to help prevent abuse. See the [pricing](https://fly.io/docs/about/pricing/) page for more details.

## Deploy the app to Fly.io

To tell Fly about your application, run `fly launch` in the directory with your source code. This creates and configures a Fly.io app.

```console
$ fly launch
```

This scans your source, detects the Phoenix project, and runs `mix phx.gen.release --docker` for you! This creates a Dockerfile for you.

The `fly launch` command walks you through a few questions.

- You can name the app or have it generate a random name for you.
- Choose an organization (defaults to `personal`). Organizations are a way of sharing applications and resources between Fly.io users.
- Choose a region to deploy to. Defaults to the nearest Fly.io region. You can check out the [complete list of regions here](https://fly.io/docs/reference/regions/).
- Sets up a Postgres DB for you.
- Builds the Dockerfile.
- Deploys your application!

The `fly launch` command also created a `fly.toml` file for you. This is where you can set ENV values and other config.

### Storing secrets on Fly.io

You may also have some secrets you'd like to set on your app.

Use [`fly secrets`](https://fly.io/docs/reference/secrets/#setting-secrets) to configure those.

```console
$ fly secrets set MY_SECRET_KEY=my_secret_value
```

### Deploying again

When you want to deploy changes to your application, use `fly deploy`.

```console
$ fly deploy
```

Note: On Apple Silicon (M1) computers, docker runs cross-platform builds using qemu which might not always work. If you get a segmentation fault error like the following:

```
 => [build  7/17] RUN mix deps.get --only
 => => # qemu: uncaught target signal 11 (Segmentation fault) - core dumped
```

You can use fly's remote builder by adding the `--remote-only` flag:

```console
$ fly deploy --remote-only
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

## Extra Fly.io tips

### Getting an IEx shell into a running node

Elixir supports getting a IEx shell into a running production node.

There are a couple prerequisites, we first need to establish an [SSH Shell](https://fly.io/docs/flyctl/ssh/) to our machine on Fly.io.

This step sets up a root certificate for your account and then issues a certificate.

```console
$ fly ssh issue --agent
```

With SSH configured, let's open a console.

```console
$ fly ssh console
Connecting to my-app-1234.internal... complete
/ #
```

If all has gone smoothly, then you have a shell into the machine! Now we just need to launch our remote IEx shell. The deployment Dockerfile was configured to pull our application into `/app`. So the command for an app named `my_app` looks like this:

```console
$ app/bin/my_app remote
Erlang/OTP 23 [erts-11.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1]

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(my_app@fdaa:0:1da8:a7b:ac4:b204:7e29:2)1>
```

Now we have a running IEx shell into our node! You can safely disconnect using CTRL+C, CTRL+C.

### Clustering your application

Elixir and the BEAM have the incredible ability to be clustered together and pass messages seamlessly between nodes. This portion of the guide walks you through clustering your Elixir application.

There are 2 parts to getting clustering quickly setup on Fly.io.

- Installing and using `libcluster`
- Scaling the application to multiple instances

#### Adding `libcluster`

The widely adopted library [libcluster](https://github.com/bitwalker/libcluster) helps here.

There are multiple strategies that `libcluster` can use to find and connect with other nodes. The strategy we'll use on Fly.io is `DNSPoll`.

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

#### Controlling the name for our node

We need to control the naming of our Elixir nodes. To help them connect up, we'll name them using this pattern: `your-fly-app-name@the.ipv6.address.on.fly`. To do this, we'll generate the release config.

```console
$ mix release.init
```

Then edit the generated `rel/env.sh.eex` file and add the following lines:

```console
ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=$FLY_APP_NAME@$ip
```

After making the change, deploy your app!

```console
$ fly deploy
```

For our app to be clustered, we have to have multiple instances. Next we'll add an additional node instance.

#### Running multiple instances

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

#### Scaling in a single region

Let's scale up to 2 instances in our current region.

```console
$ fly scale count 2
Count changed to 2
```

Checking the status, we can see what happened.

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
$ fly ssh console -C "/app/bin/my_app remote"
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:f901:4bf7:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ac4:eb41:19d3:2"]
```

The IEx prompt is included to help show the IP address of the node we are connected to. Then getting the `Node.list` returns the other node. Our two instances are connected and clustered!

#### Scaling to multiple regions

Fly makes it easy to deploy instances closer to your users. Through the magic of DNS, users are directed to the nearest region where your application is located. You can read more about [Fly.io regions here](https://fly.io/docs/reference/regions/).

Starting back from our baseline of a single instance running in `sea` which is Seattle, Washington (US), let's add the region `ewr` which is Parsippany, NJ (US). This puts an instance on both coasts of the US.

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
$ fly ssh console -C "/app/bin/my_app remote"
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:cdf6:c422:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ab2:a8e:6666:2"]
```

We have two instances of our application deployed to the West and East coasts of the North American continent and they are clustered together! Our users will automatically be directed to the server nearest them.

The Fly.io platform has built-in distribution support making it easy to cluster distributed Elixir nodes in multiple regions.

## Helpful Fly.io resources

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

Refer to the [Fly.io Elixir documentation](https://fly.io/docs/getting-started/elixir) for additional information.

[Working with Fly.io applications](https://fly.io/docs/getting-started/working-with-fly-apps/) covers things like:

* Status and logs
* Custom domains
* Certificates

## Troubleshooting

See [Troubleshooting](https://fly.io/docs/getting-started/troubleshooting/#welcome-message)

Visit the [Fly.io Community](https://community.fly.io/) to find solutions and ask questions.
