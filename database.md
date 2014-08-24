### Databases

To connect to a database you would need to add ecto.
ecto is a database abstraction that for interacting with databases and writing queries.
At the moment supports the PostgreSQL database.

### Add dependencies

In your mix.exs file add the postgrex and ecto dependencies:

```
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

A repository is a wrapper around the database.


### Add a Model

Model can provide different functionalities like the schema, validations and callbacks


### Add a Query

Queries written in ecto are sent to the repository which translates them to queries for the underlying database.
