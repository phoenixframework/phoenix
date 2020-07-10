# Deploying on Render

[Render](https://render.com) is a modern cloud platform to build and run all your apps and websites with free SSL, a global CDN, private networks and auto deploys from Git. It avoids many of the limitations of deploying Phoenix on Heroku:
- No limits on simultaneous connections or connection duration.
- Built-in clustering support.
- No forced restarts.
- Full support for [Phoenix in containers](releases#containers).

Every Phoenix app on Render comes with a number of additional features:
- Automatic [pull request previews](https://render.com/docs/pull-request-previews).
- Infrastructure as Code with [`render.yaml`](https://render.com/docs/infrastructure-as-code).
- [Fully managed PostgreSQL](https://render.com/docs/databases).
- [Private networking](https://render.com/docs/private-services), load balancing, and service discovery.
- HTTP health checks and [zero downtime deploys](https://render.com/docs/zero-downtime-deploys).
- Free, unlimited [custom domains](https://render.com/docs/custom-domains) and [teams](https://render.com/docs/teams).
- Persistent storage with [Render Disks](https://render.com/docs/disks).

We're assuming you have a working Phoenix app you'd like to deploy. If not, follow the [Up and Running guide](up_and_running.html) to get a simple app going.

> This guide focuses on deploying on Render using Mix releases. Render also supports
deploying Phoenix with [Distillery](https://render.com/docs/deploy-phoenix-distillery) and [Docker](https://render.com/docs/docker).

## Configure Mix Releases
Create [runtime configuration](releases.html#runtime-configuration) needed for Mix releases.

1. Rename `config/prod.secret.exs` to `config/releases.exs`.
2. Change `use Mix.Config` in your new `config/releases.exs` file to `import Config`. `Mix.Config` is deprecated.
3. Uncomment the following line in `config/releases.exs`:
```elixir
config :my_app, MyAppWeb.Endpoint, server: true # uncomment me!
```
4. Finally, update `config/prod.exs` to delete the line `import_config "prod.secret.exs"` at the bottom.

## Create a Build Script

We need to run a series of commands to build our app on every push to our Git repo, and we can accomplish this with a build script.

Create a script called `build.sh` at the root of your repo:

```console
#!/usr/bin/env bash
# exit on error
set -o errexit

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
npm install --prefix ./assets
npm run deploy --prefix ./assets
mix phx.digest

# Build the release and overwrite the existing release directory
MIX_ENV=prod mix release --overwrite

# Optional database migrations
# mix ecto.migrate
```

Make sure the script is executable before checking it into Git:
```console
$ chmod a+x build.sh
```

## Update Your App for Render

Update `config/prod.exs` to change the highlighted line below.
```elixir{2}
config :my_app, MyAppWeb.Endpoint,
url: [host: "example.com", port: 80],
cache_static_manifest: "priv/static/cache_manifest.json"
```
to this:
```elixir{2}
config :my_app, MyAppWeb.Endpoint,
url: [host: System.get_env("RENDER_EXTERNAL_HOSTNAME") || "localhost", port: 80],
cache_static_manifest: "priv/static/cache_manifest.json"
```
Render populates `RENDER_EXTERNAL_HOSTNAME` for `config/prod.exs`.

If you add a custom domain to your app, don't forget to change the `url` to your new domain.

## Build and Test Your Release Locally

Compile your release locally by running `./build.sh`. The output should look like this:
```console
* assembling my_app-0.1.0 on MIX_ENV=prod
* using config/releases.exs to configure the release at runtime
* skipping elixir.bat for windows (bin/elixir.bat not found in the Elixir installation)
* skipping iex.bat for windows (bin/iex.bat not found in the Elixir installation)

Release created at _build/prod/rel/my_app!

# To start your system
_build/prod/rel/my_app/bin/my_app start

Once the release is running:

# To connect to it remotely
_build/prod/rel/my_app/bin/my_app remote

# To stop it gracefully (you may also send SIGINT/SIGTERM)
_build/prod/rel/my_app/bin/my_app stop

To list all commands:

_build/prod/rel/my_app/bin/my_app
```

Test your release by running the following command and navigating to http://localhost:4000.
```console
SECRET_KEY_BASE=`mix phx.gen.secret` _build/prod/rel/my_app/bin/my_app start
```
You may need to add `DATABASE_URL=...` to the command above if you're using Ecto and a local database.

If everything looks good, push your changes to your repo. You can now deploy your app in production! 🎉

## Deploy to Render

1. Create a new **Web Service** on Render, and give Render permission to access your Phoenix repo.

2. Use the following values during creation:

| **Environment** | `Elixir` |
| **Build Command** | `./build.sh` |
| **Start Command** | `_build/prod/rel/my_app/bin/my_app start` |

3. Under the **Advanced** section, add the following environment variables:

  | Key                | Value           |
  | ------------------ | --------------- |
  | `SECRET_KEY_BASE`  | A sufficiently strong secret. |

That's it! Your Phoenix web service built with Mix releases will be live on your Render URL as soon as the build finishes.

See [Elixir Clustering](https://render.com/docs/deploy-elixir-cluster) to deploy an automatically managed Phoenix cluster on Render.

If you need help, email [support@render.com](mailto:support@render.com) or join [Render Community chat](https://render.com/chat).
