#This Guide is Under Construction

####In the meantime, these links might help.
- [Ecto Documentation](http://hexdocs.pm/ecto)
- [Elixir Dose, Introduction to Ecto](http://elixirdose.com/post/introduction-to-ecto)
- [Elixir Dose, Ecto With Phoenix, Part1](http://elixirdose.com/post/lets-build-web-app-with-phoenix-and-ecto)
- [Elixir Dose, Ecto With Phoenix, Part2](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-2)
- [Elixir Dose, Ecto With Phoenix, Part3](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-3)
- [Elixir Dose, Ecto With Phoenix, Part4](http://elixirdose.com/post/phoenix-part-4-registration-and-login)




##Ecto Models

Most web applications make use of some kind of datastore to hold data that the application needs to function. Phoenix does not currently ship with a model layer for interacting with a database as some server side MVC frameworks do. Fortunately, one of Elixir's core projects is Ecto, a dsl for interacting with databases. Currently, Ecto only supports the PostgreSQL relational database via the `postgrex` adapter, but there are plans to expand the list of supported databases in the future.

Before we begin, we'll need to have PostgreSQL  installed on our system. We'll need to create a database for our application as well as a user with a password which our application can log in as.

The [PostgreSQL documentation](http://www.postgresql.org/) has information on how to do all of that.


### Adding Ecto to Our Application

The first step toward using Ecto is to add it and the Postgrex adapter as dependencies of our application and compile them in. In our `mix.exs` file, we add `:postgrex` and `:ecto` to our list of dependencies.

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

After that, we need to download these new dependencies and compile them. At the root of our application, we need to run this familiar mix task.

```console
$ mix do deps.get, compile
```

### Adding a Repository

A repository is a wrapper around a specific instance of a database. The repository holds all the connection information, and it is responsible for all communication between the application and the database. When we connect to the database on startup, run migrations, or run queries, these will all be handled by the repository.

In order to add a repository to our application, we need to create a new file at `web/models/repo.ex`. (After this is done, we can remove the `.gitkeep` file that Phoenix generated in our app.)

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

The `priv/0` function defines the directory into which Ecto will create a `migrations` directory for our migration files. We'll talk more about migrations in just a moment.

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

Ecto models are modules which represent a single database table. This includes the fields, their types, and any associations to other models.

Let's make a simple users model with some relevant fields and no associations. `web/models/user.ex`

```elixir
defmodule HelloPhoenix.User do
  use Ecto.Model

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :created_at, :datetime, default: Ecto.DateTime.local
    field :updated_at, :datetime, default: Ecto.DateTime.local
  end
end
```

Elixir does not currently have its own module for date and time functions, so we've used Ecto's `DateTime{}` here to set the default `created_at` and `updated_at` timestamps.

### Generating a Migration

Migrations are files which define changes to our database schema. They can run virtually any DDL statements including `CREATE`, `ALTER` or `DELETE` for tables or indexes. Each migration will define two functions, `up/0` and `down/0`.

`up/0` is the path forward, the changes we want to make to the existing schema. `down/0` is the rollback path back to a previous state of the schema.

Ecto provides a handy mix task to generate a blank migration file for us.

```console
$ mix ecto.gen.migration HelloPhoenix.Repo initial_users_create
* creating priv/repo/migrations
* creating priv/repo/migrations/20141125235524_initial_users_create.exs
```

Note that Ecto created a `priv/repo/migrations` as we told it to in the `app_dir/2` function we invoked in the `priv/0` function of `HelloPhoenix.Repo`. That's where all our migrations should go.

Note also that the first part of the migration file itself is a timestamp. Ecto uses this to keep track of which migrations to run, so it is a good idea to just use the generator mix task each time we need a migration, just to get the timestamp right.

Here's the empty migration file Ecto created.

```elixir
defmodule HelloPhoenix.Repo.Migrations.InitialUsersCreate do
  use Ecto.Migration

  def up do
    ""
  end

  def down do
    ""
  end
end
```

We need to fill out the strings in the `up/0` and `down/0` functions with the SQL statements which will create and drop out `users` table.

```elixir
defmodule HelloPhoenix.Repo.Migrations.InitialUsersCreate do
  use Ecto.Migration

  def up do
    "CREATE TABLE users( \
      id serial primary key, \
      first_name varchar(255), \
      last_name varchar(255), \
      email varchar(255), \
      created_at timestamp, \
      updated_at timestamp)"
  end

  def down do
    "DROP TABLE users"
  end
end
```
Then we need to run our migration.

```console
$ mix ecto.migrate HelloPhoenix.Repo
```
Note that we need to specify which repo to migrate with. It's entirely possible that we could have multiple data stores in our application, each with its own repo.

Now we can take a look in our database to see our newly created table. Once we have established a connection on the command line or a gui db query tool, the first thing we need to do is make sure we are looking at the right database using the `\connect` command.

```console
# \connect phoenix_demo;
You are now connected to database `phoenix_demo` as user "phoenix".
```

Then we can view all the entities in the `phoenix_demo` database with the `\d` command.

```colsole
phoenix_demo=# \d
                   List of relations
 Schema |           Name           |   Type   |  Owner  
--------+--------------------------+----------+---------
 public | schema_migrations        | table    | phoenix
 public | schema_migrations_id_seq | sequence | phoenix
 public | users                    | table    | phoenix
 public | users_id_seq             | sequence | phoenix
(4 rows)
```
Great. Our `users` table is there, along with a sequence to keep track of the values for the `id` column.

Note that Ecto has also created a table and a sequence on our behalf to keep track of migrations.

Let's quickly check the columns in the `users` table that the migration created.

```console
phoenix_demo=# \d users
                                     Table "public.users"
   Column   |            Type             |                     Modifiers
------------+-----------------------------+----------------------------------------------------
 id         | integer                     | not null default nextval('users_id_seq'::regclass)
 first_name | character varying(255)      |
 last_name  | character varying(255)      |
 email      | character varying(255)      |
 created_at | timestamp without time zone |
 updated_at | timestamp without time zone |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
```
Looks good.

Ok, let's see what the `schema_migrations` table looks like.

```console
# \d schema_migrations
                          Table "public.schema_migrations"
 Column  |  Type   |                           Modifiers
---------+---------+----------------------------------------------------------------
 id      | integer | not null default nextval('schema_migrations_id_seq'::regclass)
 version | bigint  |
Indexes:
    "schema_migrations_pkey" PRIMARY KEY, btree (id)

```

Now let's see what the data actually looks like.

```console
# SELECT * FROM schema_migrations;
 id |    version
----+----------------
  1 | 20141125235524
(1 row)
```
The `version` column clearly stores the timestamp which is the first part of the name of our migration. If we were to have a number of migrations, we would still only have one row in this table, but the value in the `version` column would be the timestamp of the last migration run. This makes it easy for Ecto to keep track of which migrations it should run at any given time.

Just for fun, let's test our `down` migration.

```console
$ mix ecto.rollback HelloPhoenix.Repo
* running DOWN _build/dev/lib/hello_phoenix/priv/repo/migrations/20141125235524_initial_users_create.exs

```

Now if we take a look in the database, we see that our `users` table and its sequence are both gone.

```console
# \d
                   List of relations
 Schema |           Name           |   Type   |  Owner  
--------+--------------------------+----------+---------
 public | schema_migrations        | table    | phoenix
 public | schema_migrations_id_seq | sequence | phoenix
```

Let's migrate back up again so that our `users` table comes back.

```console
$ mix ecto.migrate HelloPhoenix.Repo
* running UP _build/dev/lib/hello_phoenix/priv/repo/migrations/20141125235524_initial_users_create.exs

```

Ok, our `users` table is back again.

```console
# \d
                   List of relations
 Schema |           Name           |   Type   |  Owner  
--------+--------------------------+----------+---------
 public | schema_migrations        | table    | phoenix
 public | schema_migrations_id_seq | sequence | phoenix
 public | users                    | table    | phoenix
 public | users_id_seq             | sequence | phoenix
(4 rows)
```

### Adding a Query Module
