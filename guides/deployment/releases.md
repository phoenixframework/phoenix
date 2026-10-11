# Deploying with Releases

Our main goal for this guide is to package your Phoenix application into a self-contained directory that includes the Erlang VM, Elixir, all of your code and dependencies. This package can then be dropped into a production machine. If you are using containers, see the ["Deploying with Containers"](containers.md) guide to assemble release inside a container image.

## What we'll need

The only thing we'll need for this guide is a working Phoenix application. For those who need a simple application to deploy, please follow the [Up and Running guide](up_and_running.html).

## Releases, assemble!

If you are not familiar with Elixir releases yet, we recommend you to read [Elixir's excellent docs](https://mix.hexdocs.pm/Mix.Tasks.Release.html) before continuing.

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

Now you can get all of the files under the `_build/prod/rel/my_app` directory, package it, and run it in any production machine with the same OS and architecture as the one that assembled the release. For more details, check the [docs for `mix release`](https://mix.hexdocs.pm/Mix.Tasks.Release.html).

## Database migrations

`mix phx.gen.release` generated two scripts for us: `server` and `migrate`. The exact moment you run those commands will depend on the deployment platform of your choice. Some platforms, like Fly.io, have custom hooks for migrating the database. Other platforms require you to migrate the database when you start your server. A simple way to do so is by updating the last lines of the generated `server` instructions, for example:

```bash
./my_app eval MyApp.Release.migrate
PHX_SERVER=true exec ./my_app start
```

where you replace `my_app` by your application name.

Migrations are executed via custom commands, which we will learn more about next.

## Custom commands

A common need in production systems is to execute custom commands required to set up the production environment. One of such commands is precisely migrating the database. Since we don't have `Mix`, a *build* tool, inside releases, which are production artifacts, we need to bring said commands directly into the release.

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
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
```

Where you replace the first two lines by your application names.

Now you can assemble a new release with `MIX_ENV=prod mix release` and you can invoke any code, including the functions in the module above, by calling the `eval` command:

```console
$ _build/prod/rel/my_app/bin/my_app eval "MyApp.Release.migrate"
```

You can use this same approach for migrations to create any custom command to run in production. The idea is that each command invokes `load_app`, which calls `Application.ensure_loaded/1` to load the current application without starting it.

> #### Starting your application {: .info}
>
> Some commands may need to start the whole application. In such cases, `Application.ensure_all_started/1` must be used instead of `Application.load/1`. Keep in mind starting the application will start all processes in its supervision tree, including the Phoenix endpoint. This can be circumvented by changing your supervision tree to not start certain children under certain conditions. For example, in the release commands file you could do:
>
> ```elixir
> defp start_app do
>   load_app()
>   Application.put_env(@app, :minimal, true)
>   Application.ensure_all_started(@app)
> end
> ```
>
> And then in your application you check `Application.get_env(@app, :minimal)` and start only part of the children when it is set.

## Clustering

It is also important to configure your release for clustering, especially if you are using the long-polling transport (which is enabled by default but can be disabled). The exact details will depend on the plateform you deploy to. See our [clustering](clustering.md) guide.