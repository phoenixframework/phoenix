#This Guide is Under Construction

####In the meantime, these links might help.
- [Ecto Documentation](http://hexdocs.pm/ecto)
- [Elixir Dose, Introduction to Ecto](http://elixirdose.com/post/introduction-to-ecto)
- [Elixir Dose, Ecto With Phoenix, Part1](http://elixirdose.com/post/lets-build-web-app-with-phoenix-and-ecto)
- [Elixir Dose, Ecto With Phoenix, Part2](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-2)
- [Elixir Dose, Ecto With Phoenix, Part3](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-3)
- [Elixir Dose, Ecto With Phoenix, Part4](http://elixirdose.com/post/phoenix-part-4-registration-and-login)




##Ecto Models

Most web applications make use of some kind of datastore to hold data that the application needs to function. Phoenix does not currently ship with a model layer for interacting with a database as some server side MVC frameworks do. Fortunately, one of Elixir's core projects is Ecto, a dsl for communicating with databases. Currently, Ecto only supports the PostgreSQL relational database via the `postgrex` adapter, but there are plans to expand the list of supported databases in the future.

Before we begin, we'll need to have PostgreSQL  installed on our system. We'll need to create a database for our application as well as a user with a password which our application can log in as.

The [PostgreSQL documentation](http://www.postgresql.org/) has information on how to do all of that.


### Adding Ecto to Our Application

The first step toward using Ecto is to add it and the postgrex adapter as dependencies of our application and compile them in. In our `mix.exs` file, we add `postgrex` and `ecto` to our list of dependencies.

```elixir
defp deps do
  [
    {:phoenix, github: "phoenixframework/phoenix"},
    {:cowboy, "~> 1.0.0"},
    {:postgrex, "~> 0.6.0"},
    {:ecto, "~> 0.2.5"}
  ]
end
```

Then we need to add them to our list of applications. (still in `mix.exs`)

```elixir
def application do
  [
    mod: {HelloPhoenix, [] },
    applications: [:phoenix, :cowboy, :postgrex, :ecto]
  ]
end
```

After that, we need to get these new dependencies and compile them. At the root of our application, we need to run this familiar mix task.

```console
$ mix do deps.get, compile
```

### Adding a Repository

A repository is a wrapper around a specific instance of a database. The repository holds all the connection information, and it is responsible for all communication between the application and the database. When we connect to the database on startup, run migrations, or run queries, these will all be handled by the repository.

Let's add a repository to our application now. We need to create a new file at `web/models/repo.ex`. (After this is done, we can remove the `.gitkeep` file that Phoenix generated in our app.)

Here's what an example repo for our `HelloPhoenix` app might look like.

```elixir
defmodule HelloPhoenix.Repo do
  use Ecto.Repo, adapter: Ecto.Adapters.Postgres

  def conf do
    parse_url "ecto://username:password@host/database_name"
  end

  def priv do
    app_dir(:hello_phoenix, "priv/repo")
  end
end
```

The `conf/0` function defines the details Ecto needs to connect to the database. Of course, we need to fill in our own actual values for 'username', 'password', 'host', and 'database_name'.

The `priv/0` function defines the directory into which we will put migration files. We'll talk more about migrations in just a moment.

The last bit of configuration we need to do is make sure that our `HelloPhoenix.Repo` starts up when our app does, and that it is supervised properly.

To do so, we need to edit the `lib/hello_phoenix.ex` file. All we need to do is to add our `HelloPhoenix.Repo` as a worker in the list of children to be supervised, like this.

```elixir
children = [worker(HelloPhoenix.Repo, [])]
```
With that, the `start/2` function should look like this.

```elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false

  children = [worker(HelloPhoenix.Repo, [])]
  opts = [strategy: :one_for_one, name: HelloPhoenix.Supervisor]

  Supervisor.start_link(children, opts)
end
```

At this point, let's make sure what we've done so far works by running `mix phoenix.start` at the root of our application. It should start up without errors and show the Phoenix welcome page at [localhost:4000](http://localhost:4000)

### Adding a Model


### Generating a Migration


### Adding a Query
