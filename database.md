### Databases

To connect to a database you would need to add ecto.
ecto is a database abstraction that for interacting with databases and writing queries.
At the moment supports the PostgreSQL database.

### Add dependencies

In your mix.exs file add the postgrex and ecto dependencies:

```elixir
def application do
  [
    mod: {YourPhoenixApp, [] },
    applications: [:phoenix, :cowboy, :postgrex, :ecto]
  ]
end

defp deps do
  [
    {:phoenix, github: "phoenixframework/phoenix"},
    {:cowboy, "~> 1.0.0"},
    {:postgrex, "~> 0.5.4"},
    {:ecto, "~> 0.2.0"}
  ]
end
```

And then install the dependenciew with:

```
mix deps.get
```

### Add a Repository

A repository is a wrapper around the database. It can be defined as follows in a file called web/models/repo.ex:

```elixir
defmodule MyPhoenixApp.Repo do
  use Ecto.Repo, adapter: Ecto.Adapters.Postgres

  def conf do
    parse_url "ecto://username:password@host/database_name"
  end

  def priv do
    app_dir(:my_phoenix_app, "priv/repo")
  end
end
```

where the conf defines the connection details to the database and the priv defines the directory for the migrations.

Each repository in Ecto defines a `start_link/0` function that needs to be invoked before using the repository. In general this function is not called directly, but via the supervisor chain. Edit your lib/app_name.ex to be similar to the following:

```elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false
  tree = [worker(MyPhoenixApp.Repo, [])]
  opts = [strategy: :one_for_one, name: MyPhoenixApp.Sup]
  Supervisor.start_link(tree, opts)
end
```

### Add a Model

Model can provide different functionalities like the schema, validations and callbacks


### Add a Query

Queries written in ecto are sent to the repository which translates them to queries for the underlying database.
