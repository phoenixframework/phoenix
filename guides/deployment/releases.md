# Deploying with Releases

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those of us who need a simple application to deploy, please follow the [Up and Running guide](up_and_running.html).

## Goals

Our main goal for this guide is to package your Phoenix application into a self-contained directory that includes the Erlang VM, Elixir, all of your code and dependencies. This package can then be dropped into a production machine.

## Releases, assemble!

If you are not familiar with Elixir releases yet, we recommend you to read [Elixir's excellent docs](https://hexdocs.pm/mix/Mix.Tasks.Release.html) before continuing.

Once that is done, you can assemble a release by going through all of the steps in our general [deployment guide](deployment.html) with `mix release` at the end. Let's recap.

First set the environment variables:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Then load dependencies to compile code and assets:

```console
# Initial setup
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compile assets
$ MIX_ENV=prod mix assets.deploy
```

And now run `mix phx.gen.release`:

```console
$ mix phx.gen.release
==> my_app
* creating rel/overlays/bin/server
* creating rel/overlays/bin/server.bat
* creating rel/overlays/bin/migrate
* creating rel/overlays/bin/migrate.bat
* creating lib/my_app/release.ex

Your application is ready to be deployed in a release!

    # To start your system
    _build/dev/rel/my_app/bin/my_app start

    # To start your system with the Phoenix server running
    _build/dev/rel/my_app/bin/server

    # To run migrations
    _build/dev/rel/my_app/bin/migrate

Once the release is running:

    # To connect to it remotely
    _build/dev/rel/my_app/bin/my_app remote

    # To stop it gracefully (you may also send SIGINT/SIGTERM)
    _build/dev/rel/my_app/bin/my_app stop

To list all commands:

    _build/dev/rel/my_app/bin/my_app

```

The `phx.gen.release` task generated a few files for us to assist in releases. First, it created `server` and `migrate` *overlay* scripts for conveniently running the phoenix server inside a release or invoking migrations from a release. The files in the `rel/overlays` directory are copied into every release environment. Next, it generated a `release.ex` file which is used to invoke Ecto migrations without a dependency on `mix` itself.

*Note*: If you are a Docker user, you can pass the `--docker` flag to `mix phx.gen.release` to generate a Dockerfile ready for deployment.

Next, we can invoke `mix release` to build the release:

```console
$ MIX_ENV=prod mix release
Generated my_app app
* assembling my_app-0.1.0 on MIX_ENV=prod
* using config/runtime.exs to configure the release at runtime

Release created at _build/prod/rel/my_app!

    # To start your system
    _build/prod/rel/my_app/bin/my_app start

...
```

You can start the release by calling `_build/prod/rel/my_app/bin/my_app start`, or boot your webserver by calling `_build/prod/rel/my_app/bin/server`, where you have to replace `my_app` by your current application name.

Now you can get all of the files under the `_build/prod/rel/my_app` directory, package it, and run it in any production machine with the same OS and architecture as the one that assembled the release. For more details, check the [docs for `mix release`](https://hexdocs.pm/mix/Mix.Tasks.Release.html).

But before we finish this guide, there is one more feature from releases that most Phoenix application will use, so let's talk about that.

## Ecto migrations and custom commands

A common need in production systems is to execute custom commands required to set up the production environment. One of such commands is precisely migrating the database. Since we don't have `Mix`, a *build* tool, inside releases, which are a production artifact, we need to bring said commands directly into the release.

The `phx.gen.release` command created the following `release.ex` file in your project `lib/my_app/release.ex`, with the following content:

```elixir
defmodule MyApp.Release do
  @app :my_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

Where you replace the first two lines by your application names.

Now you can assemble a new release with `MIX_ENV=prod mix release` and you can invoke any code, including the functions in the module above, by calling the `eval` command:

```console
$ _build/prod/rel/my_app/bin/my_app eval "MyApp.Release.migrate"
```

And that's it! If you peek inside the `migrate` script, you'll see it wraps exactly this invocation.

You can use this approach to create any custom command to run in production. In this case, we used `load_app`, which calls `Application.load/1` to load the current application without starting it. However, you may want to write a custom command that starts the whole application. In such cases, `Application.ensure_all_started/1` must be used. Keep in mind, starting the application will start all processes for the current application, including the Phoenix endpoint. This can be circumvented by changing your supervision tree to not start certain children under certain conditions. For example, in the release commands file you could do:

```elixir
defp start_app do
  load_app()
  Application.put_env(@app, :minimal, true)
  Application.ensure_all_started(@app)
end
```

And then in your application you check `Application.get_env(@app, :minimal)` and start only part of the children when it is set.

## Containers

Elixir releases work well with container technologies, such as Docker. The idea is that you assemble the release inside the Docker container and then build an image based on the release artifacts.

If you call `mix phx.gen.release --docker` you'll see a new file with these contents:

```Dockerfile
# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20230612-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.14.5-erlang-25.3.2.4-debian-bullseye-20230612-slim
#
ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=25.3.2.4
ARG DEBIAN_VERSION=bullseye-20230612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/my_app ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
```

Where `my_app` is the name of your app. At the end, you will have an application in `/app` ready to run as `/app/bin/server`.

A few points about configuring a containerized application:

- If you run your app in a container, the `Endpoint` needs to be configured to listen on a "public" `:ip` address (like `0.0.0.0`) so that the app can be reached from outside the container. Whether the host should publish the container's ports to its own public IP or to localhost depends on your needs.
- The more configuration you can provide at runtime (using `config/runtime.exs`), the more reusable your images will be across environments. In particular, secrets like database credentials and API keys should not be compiled into the image, but rather should be provided when creating containers based on that image. This is why the `Endpoint`'s `:secret_key_base` is configured in `config/runtime.exs` by default.
- If possible, any environment variables that are needed at runtime should be read in `config/runtime.exs`, not scattered throughout your code. Having them all visible in one place will make it easier to ensure the containers get what they need, especially if the person doing the infrastructure work does not work on the Elixir code. Libraries in particular should never directly read environment variables; all their configuration should be handed to them by the top-level application, preferably [without using the application environment](https://hexdocs.pm/elixir/library-guidelines.html#avoid-application-configuration).
