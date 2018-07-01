# Introduction to Deployments with docker

First things first, we need a running application to deploy it. If you don't yet have one, head to
[Up and Running Guide](up_and_running.html).

Docker enables you to deploy to the platform of your choice AWS, Google cloud, Digital ocean...

In this guide we will cover a simple deployement to a single machine. There are two steps for that.

- Building an image
  Docker defines images and container. An image is a set of definitions for an environement (installed libraries...). A container is a running instance of an image. One of the intricacy of building an image is handling environement variables.

- Running that image on a container on the server
  Once the image is built, we will want to compose it with other images (a postgres image for our db) when running on production. We will cover in this part the steps to deployment on the actual server.

## Building our production image

The recommended way to deploy elixir applications is with a release. To build our release we will use [Distillery](https://github.com/bitwalker/distillery). We will first add the necessary to build a release, then handle environment variables, then finally build our release inside our image.

### Building a release

The distillery [doc](https://hexdocs.pm/distillery/getting-started.html) is good and short, read and follow the instructions. Here are the steps you should have taken so far

- add distillery dependency to your mix.exs file (below defp deps do)
  `{:distillery, "~> MAJ.MIN", runtime: false}`
  (replace MAJ and MIN with the latest major and minor version of the library)

- run the `mix release.init` task

- make modifications for the migrations. Detailed [here](https://hexdocs.pm/distillery/running-migrations.html#content) (add rel/commands/migrate.sh and modify rel.config.exs)

- don't make the change regarding environement variables just yet, we are going to use a different simpler way of handling them in the next section

## Handling environement variables

For environement variables we are going to use "${MY_ENV_VAR}" in prod.exs and have an additional `REPLACE_OS_VARS=true` in our environement variables
so our prod.exs file should look like (most of the original phoenix doc has been removed)

```
use Mix.Config

config :union, UnionWeb.Endpoint,
  load_from_system_env: true,
  http: [port: "${PORT}"],
  url: [host: "${HOSTNAME}"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  server: true,
  root: ".",
  secret_key_base: "${SECRET_KEY_BASE}",
  version: Application.spec(:phoenix_app, :vsn)

# Do not print debug messages in production
config :logger, level: :info

# Configure your database
config :union, Union.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "${POSTGRES_USER}",
  password: "${POSTGRES_PASSWORD}",
  database: "${POSTGRES_DB}",
  hostname: "db",
  pool_size: 80,
  timeout: 60_000,
  pool_timeout: 60_000

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
config :phoenix, :serve_endpoints, true
```

rel.config.exs looks like

```
# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  # This sets the default release built by `mix release`
  default_release: :default,
  # This sets the default environment used by `mix release`
  default_environment: :prod

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set(dev_mode: true)
  set(include_erts: false)
  set(include_system_libs: false)
  set(cookie: :dev)
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: "${ERLANG_COOKIE}")
  set(vm_args: "rel/vm.args.eex")

  set(
    commands: [
      seed: "rel/commands/seed.sh",
      migrate: "rel/commands/migrate.sh"
    ]
  )
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :my_app_name do
  set(version: current_version(:my_app_name))

  set(
    applications: [
      :runtime_tools
    ]
  )
end
```

let's add a docker.env to the root of our project that would look like

```
HOSTNAME=my_hostname
SECRET_KEY_BASE=
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=
PORT=4000
LANG=en_US.UTF-8
REPLACE_OS_VARS=true
ERLANG_COOKIE=
```

We will make use of this file, in the second part when running the image
(of course all those values should be filled up with your details)
to generate a secret for the secret_key_base and the erlang_cookie you can use
`mix phx.gen.secret` in an iex shell
(make sure you add `docker.env` to your .gitignore, you don't want to commit your env vars)

### Finally building our image

add a dockerfile to your project that should contain the following

```
FROM elixir:1.6.6-alpine
ARG APP_NAME=union
ARG PHOENIX_SUBDIR=.
ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm
WORKDIR /opt/app
# use yarn instead of npm
RUN apk update \
  && apk --no-cache --update add nodejs yarn git build-base \
  && mix local.rebar --force \
  && mix local.hex --force
COPY . .
RUN mix do deps.get, deps.compile, compile
RUN cd ${PHOENIX_SUBDIR}/assets \
  && yarn install \
  && yarn deploy \
  && cd .. \
  && mix phx.digest
RUN mix release --env=prod --verbose \
  && mv _build/prod/rel/${APP_NAME} /opt/release \
  && mv /opt/release/bin/${APP_NAME} /opt/release/bin/start_server
FROM alpine:3.7
# bash is required by distillery
RUN apk update && apk --no-cache --update add bash openssl-dev
ENV PORT=4000 MIX_ENV=prod REPLACE_OS_VARS=true
WORKDIR /opt/app
EXPOSE ${PORT}
COPY --from=0 /opt/release .
CMD ["/opt/app/bin/start_server", "foreground"]
```

(Make sure to check which version of elixir you want to use)

Here are the steps taken here

- get and compile elixir dependencies
- get frontend dependencies and build frontend assets
- make a release
- move that release to an alpine image for image size efficiency

### Test that your build works

You need to push that image to a registery in order to run it on another machine than yours. At hub.docker.com you can create an account and you get one free private image.

To test your build use:

- `docker build -t my_docker_hub_handle/my_app:1 .`

To push that image to docker hub:

- `docker login` (you will need to enter your username and password)
- `docker push my_docker_hub_handle/my_app:1`

## Running that image on the server

### First run on local

we need to run our image with a database image. To compose images together, we use docker-compose.
add a `docker-compose.yml` with the following content to the root of your project.

```
version: '3.1'

services:
  web:
    image: "my_docker_hub_handle/my_app:1"
    ports:
      - "80:4000"
      - "443:443"
    volumes:
    - .:/app
    env_file:
     - ./docker.env
    stdin_open: true
    tty: true
    links:
      - db

  db:
    image: postgres:10-alpine
    volumes:
      - "./volumes/postgres:/var/lib/postgresql/data"
    ports:
      - "5432:5432"
    env_file:
     - ./docker.env
```

this is where the previously created environement variable file will be used.

The first time you run the postgres container, it will create a database and a user for you if you have the POSTGRES_USER, POSTGRES_PASSWORD and POSTGRES_DB variables set up. That's why it's important to use exactly these environement variable names.

first you need to initialize your db container (that will create the initial database)
`docker-compose up db`
once the message that the database is ready appears, you can Ctrl-c to exit the container

Now you can run your setup with
`docker-compose up`

go visit `localhost` on your browser and verify that your application is running.You can then exit the running containers with Ctrl-c.

### Running your images on the server

Prerequisite: you need to have docker and docker-compose installed on your server. (digital ocean has these one-click droplets for example, that are vps you can setup with one click that already have docker and docker-compose)

copy the docker.env and the docker-compose.yml file on your server
for example
`scp docker.env user_name@server_ip:/etc/opt/my_app_name/`
`scp docker-compose.yml user_name@server_ip:/etc/opt/my_app_name/`
(etc is used to store configuration file, opt is for optional applications that are not core to the os)

- make sure to setup the db on the server too
  `docker-compose up db`

- then start the containers
  `docker-compose up -d`
  (the -d is for detached mode, to not kill the containers when you exit the ssh connection)

if you need to take the server down
`docker-compose down`

### Releasing the next version

Now that you have a first version working, let's release the next one.

If you make changes to your code and/or add migrations for example, you simply need to

- rebuild the image and push it
  `docker build -t my_docker_hub_handle/my_app:2 .`
  `docker push my_docker_hub_handle/my_app:2` (you might need to login to docker)

- then on production in your folder with docker-compose.yml
  `docker-compose down` (take the server down)
  `docker-compose pull` (pull the latest version of the image)
  `docker-compose up` (restart the server)

- run the migration if any
  `docker-compose run web /opt/app/bin/start_server migrate`
