# Using MySQL

Phoenix applications are configured to use PostgreSQL by default, but what if we want to use MySQL instead? In this guide, we'll walk through changing that default whether we are about to create a new application, or whether we have an existing one configured for PostgreSQL.

If we are about to create a new application, configuring our application to use MySQL is easy. We can simply pass the `--database mysql` flag to `phx.new` and everything will be configured correctly.

```
$ mix phx.new hello_phoenix --database mysql

```
This will set up all the correct dependencies and configuration for us automatically. Once we install those dependencies with `mix deps.get`, we'll be ready to begin working with Ecto in our application.

If we have an existing application, all we need to do is switch adapters and make some small configuration changes.

To switch adapters, we need to remove the Postgrex dependency and add a new one for Mariaex instead.

Let's open up our `mix.exs` file and do that now.

```
defmodule HelloPhoenix.Mixfile do
  use Mix.Project

  . . .
  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:mariaex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"}
    ]
  end
end
```

Next, we need to configure our new adapter. Let's open up our `config/dev.exs` file and do that.

```
config :hello_phoenix, HelloPhoenix.Repo,
adapter: Ecto.Adapters.MySQL,
username: "root",
password: "",
database: "hello_phoenix_dev"
```

If we have an existing configuration block for our `HelloPhoenix.Repo`, we can simply change the values to match our new ones. The most important thing is to make sure we are using the MySQL adapter `adapter: Ecto.Adapters.MySQL,`.

We also need to configure the correct values in the `config/test.exs` and `config/prod.secret.exs` files as well.

Now all we need to do is fetch our new dependency, and we'll be ready to go.

```
$ mix do deps.get, compile
```

With our new adapter installed and configured, we're ready to create our database.

```
$ mix ecto.create
```

The database for HelloPhoenix.repo has been created.
We're also ready to run any migrations, or do anything else with Ecto that we might choose.

```
$ mix ecto.migrate
[info] == Running HelloPhoenix.Repo.Migrations.CreateUser.change/0 forward
[info] create table users
[info] == Migrated in 0.2s
```