Phoenix applications are configured to use PostgreSQL by default, but what if we want to use MySQL instead? In this guide, we'll walk through changing that default whether we are about to create a new application, or whether we have an existing one configured for PostgreSQL.

If we are about to create a new application, configuring our application to use MySQL is easy. We can simply pass the `--database mysql` flag to `phoenix.new` and everything will be configured correctly.

```console
$ mix phoenix.new hello_phoenix --database mysql
```

This will set up all the correct dependencies and configuration for us automatically. Once we install those dependencies with `mix deps.get`, we'll be ready to begin working with Ecto in our application.

If we have an existing application, all we need to do is switch adapters and make some small configuration changes.

To switch adapters, we need to remove the Postgrex dependency and add a new one for Mariaex instead.

Let's open up our `mix.exs` file and do that now.

```elixir
defmodule HelloPhoenix.Mixfile do
  use Mix.Project

  . . .
  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:phoenix, "~> 1.0.2"},
     {:phoenix_ecto, "~> 1.1"},
     {:mariaex, ">= 0.0.0"},
     {:phoenix_html, "~> 2.1"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:cowboy, "~> 1.0"}]
  end
end
```

We also need to remove the `:postgrex` app from our list of applications and substitute the `:mariaex` app instead. Let's do that in `mix.exs` as well.

```elixir
defmodule HelloPhoenix.Mixfile do
  use Mix.Project

. . .
def application do
  [mod: {MysqlTester, []},
  applications: [:phoenix, :cowboy, :logger,
  :phoenix_ecto, :mariaex]]
end
. . .
```

Next, we need to configure our new adapter. Let's open up our `config/dev.exs` file and do that.

```elixir
config :hello_phoenix, HelloPhoenix.Repo,
adapter: Ecto.Adapters.MySQL,
username: "root",
password: "",
database: "hello_phoenix_dev"
```

If we have an existing configuration block for our `HelloPhoenix.Repo`, we can simply change the values to match our new ones. The most important thing is to make sure we are using the MySQL adapter `adapter: Ecto.Adapters.MySQL,`.

We also need to configure the correct values in the `config/test.exs` and `config/prod.secret.exs` files as well.

Now all we need to do is fetch our new dependency, and we'll be ready to go.

```console
$ mix do deps.get, compile
```

With our new adapter installed and configured, we're ready to create our database.

```console
$ mix ecto.create
The database for HelloPhoenix.repo has been created.
```

We're also ready to run any migrations, or do anything else with Ecto that we might choose.

```console
$ mix ecto.migrate
[info] == Running HelloPhoenix.Repo.Migrations.CreateUser.change/0 forward
[info] create table users
[info] == Migrated in 0.2s
```
