# Swapping Databases

Phoenix applications are configured to use PostgreSQL by default, but what if we want to use another database, such as MySQL? In this guide, we'll walk through changing that default whether we are about to create a new application, or whether we have an existing one configured for PostgreSQL.

## Using `phx.new`

If we are about to create a new application, configuring our application to use MySQL is easy. We can simply pass the `--database mysql` flag to `phx.new` and everything will be configured correctly.

```console
$ mix phx.new hello_phoenix --database mysql
```

This will set up all the correct dependencies and configuration for us automatically. Once we install those dependencies with `mix deps.get`, we'll be ready to begin working with Ecto in our application.

## Within an existing application

If we have an existing application, all we need to do is switch adapters and make some small configuration changes.

To switch adapters, we need to remove the Postgrex dependency and add a new one for MyXQL instead.

Let's open up our `mix.exs` file and do that now.

```elixir
defmodule HelloPhoenix.MixProject do
  use Mix.Project

  ...
  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.13"},
      {:myxql, ">= 0.0.0"},
      ...
    ]
  end
end
```

Next, we need to configure our adapter to use the default MySQL credentials by updating `config/dev.exs`:

```elixir
config :hello_phoenix, HelloPhoenix.Repo,
  username: "root",
  password: "",
  database: "hello_phoenix_dev"
```

If we have an existing configuration block for our `HelloPhoenix.Repo`, we can simply change the values to match our new ones. You also need to configure the correct values in the `config/test.exs` and `config/runtime.exs` files as well.

The last change is to open up `lib/hello_phoenix/repo.ex` and make sure to set the `:adapter` to `Ecto.Adapters.MyXQL`.

Now all we need to do is fetch our new dependency, and we'll be ready to go.

```console
$ mix deps.get
```

With our new adapter installed and configured, we're ready to create our database.

```console
$ mix ecto.create
```

The database for HelloPhoenix.Repo has been created.
We're also ready to run any migrations, or do anything else with Ecto that we may choose.

```console
$ mix ecto.migrate
[info] == Running HelloPhoenix.Repo.Migrations.CreateUser.change/0 forward
[info] create table users
[info] == Migrated in 0.2s
```

## Other options

While Phoenix uses the `Ecto` project to interact with the data access layer, there are many other data access options, some even built into the Erlang standard library. [ETS](https://www.erlang.org/doc/man/ets.html) – available in Ecto via [`etso`](https://hexdocs.pm/etso/) – and [DETS](https://www.erlang.org/doc/man/dets.html) are key-value data stores built into [Erlang/OTP](https://www.erlang.org/doc/). Both Elixir and Erlang also have a number of libraries for working with a wide range of popular data stores.

The data world is your oyster, but we won't be covering these options in these guides.
