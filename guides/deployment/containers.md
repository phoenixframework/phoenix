# Deploying with Containers

This guide walks you through building a container image to deploy your Phoenix application. This is done by [assembling a release](releases.md) inside an image.

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those who need a simple application to deploy, please follow the [Up and Running guide](up_and_running.html).

## Containers

Elixir releases work well with container technologies such as Docker. The idea is that you assemble the release inside the Docker container and then build an image based on the release artifacts.

To get started, simply call `mix phx.gen.release --docker`, and you'll see a new file with content similar to:

```Dockerfile
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the builder image
#     E.g.: docker.io/hexpm/elixir:1.20.2-erlang-29.0.3-debian-trixie-20260623-slim
#   - https://hub.docker.com/_/debian/tags?name=trixie-20260623-slim - for the runner image
#     E.g.: docker.io/debian:trixie-20260623-slim
#
# Find builder and runner images on Docker Hub or on Hex's Build Server (Bob).
# We recommend using Bob's Web UI to find recent tags:
#
#   - https://bob.hex.pm/docker?repo=hexpm/elixir&os=debian&sort=elixir_version,erlang_version,os_version
#
# We suggest using the same Debian version for both the builder and runner images.
#
# We suggest Debian/Ubuntu instead of Alpine to avoid production compatibility issues
# (such as DNS resolution failures, and dynamically linked NIFs/precompiled binaries).
#
# For finding packages in Debian, search on https://packages.debian.org/.

ARG ELIXIR_VERSION=1.20.3
ARG OTP_VERSION=29.0.3
ARG DEBIAN_VERSION=trixie-20260623-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

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

RUN mix assets.setup

COPY priv priv

COPY lib lib

# Compile the release
RUN mix compile

COPY assets assets

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

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

Where `my_app` is the name of your app. At the end, you will have an application in `/app` ready to run as `/app/bin/server`. For more details, see the ["Deploying with Releases"](releases.md) guide.

To deploy this image, you must:

* Configure the relevant environment variables. Your application will need at least the `SECRET_KEY_BASE` (generate one with `mix phx.gen.secret`) and `DATABASE_URL` environment variables. These environment variables are read from `config/runtime.exs`. The more configuration you can provide at runtime (using `config/runtime.exs`), the more reusable your images will be across environments. In particular, secrets like database credentials and API keys should not be compiled into the image but rather should be provided directly on your deployment platform or when creating containers

* Configure [database migrations](releases.md#database-migrations). Either in your deployment platform or update the server command to run them, as described in the linked resource

* Configure [clustering](clustering.html). The particular configuration for clustering will depend on your deployment platform. Clustering is important for long-polling to work, otherwise it must be disabled. Read the documentation for more information

And you are good to go! If you need to tune your release or provide custom commands, see [Elixir's release](https://mix.hexdocs.pm/Mix.Tasks.Release.html) documentation and the ["Deploying with Releases"](releases.md) guide.
