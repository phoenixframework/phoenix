#This Guide is Under Construction

####In the meantime, these links might help.
- [Ecto Documentation](http://hexdocs.pm/ecto)
- [Elixir Dose, Introduction to Ecto](http://elixirdose.com/post/introduction-to-ecto)
- [Elixir Dose, Ecto With Phoenix, Part1](http://elixirdose.com/post/lets-build-web-app-with-phoenix-and-ecto)
- [Elixir Dose, Ecto With Phoenix, Part2](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-2)
- [Elixir Dose, Ecto With Phoenix, Part3](http://elixirdose.com/post/phoenix-ecto-and-jobs-portal-project-part-3)
- [Elixir Dose, Ecto With Phoenix, Part4](http://elixirdose.com/post/phoenix-part-4-registration-and-login)




Most web applications make use of some kind of datastore to hold data that the application needs to function. Phoenix does not currently ship with a model layer for interacting with a database as some server side MVC frameworks do. Fortunately, one of Elixir's core projects is [Ecto](https://github.com/elixir-lang/ecto), a dsl for interacting with databases. Currently, Ecto only supports the PostgreSQL relational database via the `postgrex` adapter, but there are plans to expand the list of supported databases in the future.

Before we begin, we'll need to have PostgreSQL installed on our system. We'll need to create a database for our application as well as a user with a password which our application can log in as.

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

The `conf/0` function defines the details Ecto needs to connect to the database. Of course, we need to fill in our own actual values for `username`, `password`, `host`, and `database_name`.

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
### Experiments With Our Model

Now that we have defined a model and migrated our schema, let's experiment a little in an iex session.

At the root of our project, let's run our now familiar command.

```console
$ iex -S mix
```
You might also want to establish a direct `psql` connection to your PostgreSQL database using your own credentials and database name.

The first thing we need to do is create a new struct from our `User` model. Since we haven't aliased anything, we need to use the fully qualified name, `HelloPhoenix.User`.

```console
iex(1)> user = %HelloPhoenix.User{first_name: "Dweezil", last_name: "Zappa", email: "dweezil@example.com"}
%HelloPhoenix.User{created_at: %Ecto.DateTime{day: 28, hour: 22, min: 10,
  month: 11, sec: 31, year: 2014}, email: "dweezil@example.com",
 first_name: "Dweezil", id: nil, last_name: "Zappa",
 updated_at: %Ecto.DateTime{day: 28, hour: 22, min: 10, month: 11, sec: 31,
  year: 2014}}
```
Notice that the default values we set in the model for `created_at` and `updated_at` are currently populated with a special struct `%Ecto.DateTime` representing the current date and time.

Also, at this point, we don't have a value set for the `id` field. We haven't communicated at all with the database. We can test this with a simple query we perform directly in a `psql` session.

```console
phoenix_demo=# select * from users;
 id | first_name | last_name | email | created_at | updated_at
----+------------+-----------+-------+------------+------------
(0 rows)
```
Now that we have a struct from our model, we can use the `insert` function from our repo to create a record in the database.

```console
iex(2)> HelloPhoenix.Repo.insert user
%HelloPhoenix.User{created_at: %Ecto.DateTime{day: 28, hour: 22, min: 10,
  month: 11, sec: 31, year: 2014}, email: "dweezil@example.com",
 first_name: "Dweezil", id: 1, last_name: "Zappa",
 updated_at: %Ecto.DateTime{day: 28, hour: 22, min: 10, month: 11, sec: 31,
  year: 2014}}
```

Now we do have a value for the `id` field, which implies that our struct was saved to the database. We can verify that this actually worked directly in `psql`.

```console
phoenix_demo=# select * from users;
 id | first_name | last_name |        email        |     created_at      |     updated_at
----+------------+-----------+---------------------+---------------------+---------------------
  1 | Dweezil    | Zappa     | dweezil@example.com | 2014-11-28 22:10:31 | 2014-11-28 22:10:31
(1 row)
```

The `%Ecto.DateTime` struct has clearly been tranlated into a proper PostgreSQL datetime format for both the `created_at` and `updated_at` columns.

Now that we have a row in the database, we can try out some of Ecto's query functions. Let's try to simply get all the users. Notice we pass the whole model module to the `HelloPhoenix.Repo.all` function.

```console
iex(3)> HelloPhoenix.Repo.all HelloPhoenix.User
[%HelloPhoenix.User{created_at: %Ecto.DateTime{day: 28, hour: 22, min: 10,
   month: 11, sec: 31, year: 2014}, email: "dweezil@example.com",
  first_name: "Dweezil", id: 1, last_name: "Zappa",
  updated_at: %Ecto.DateTime{day: 28, hour: 22, min: 10, month: 11, sec: 31,
   year: 2014}}]
```
This returns us a list of all the users, represented as structs, which at this point is only Dweezil.

Since we know the id of our record, we can use the `HelloPhoenix.Repo.get` function, which also takes the model module and an integer for the id.

```console
iex(4)> HelloPhoenix.Repo.get HelloPhoenix.User, 1
%HelloPhoenix.User{created_at: %Ecto.DateTime{day: 28, hour: 22, min: 10,
  month: 11, sec: 31, year: 2014}, email: "dweezil@example.com",
 first_name: "Dweezil", id: 1, last_name: "Zappa",
 updated_at: %Ecto.DateTime{day: 28, hour: 22, min: 10, month: 11, sec: 31,
  year: 2014}}
```
This time, we get back a single struct because the id is unique for a given model.

Let's see if we can update our user, changing both the first name and email address. Step one is changing the values for the given keys in our struct.

```console
iex(9)> user = Map.merge(user, %{first_name: "Frank", email: "frank@example.com"})
%HelloPhoenix.User{created_at: %Ecto.DateTime{day: 28, hour: 22, min: 10,
  month: 11, sec: 31, year: 2014}, email: "frank@example.com",
 first_name: "Frank", id: 1, last_name: "Zappa",
 updated_at: %Ecto.DateTime{day: 28, hour: 22, min: 10, month: 11, sec: 31,
  year: 2014}}
```
Step two is updating it in the database with the `HelloPhoenix.Repo.update` function.

```console
iex(10)> HelloPhoenix.Repo.update user
:ok
```
We got the atom `:ok` back, so it looks good. Let's check to see what our record looks like.

```console
phoenix_demo=# select * from users;
 id | first_name | last_name |       email       |     created_at      |     updated_at
----+------------+-----------+-------------------+---------------------+---------------------
  1 | Frank      | Zappa     | frank@example.com | 2014-11-28 22:10:31 | 2014-11-28 22:10:31
(1 row)
```
The `first_name` and `email` columns are right, but notice that the `updated_at` column didn't change as we might have expected it to. We need to manually manage that in our code.

The only thing really left to try is deleting our user.

```console
iex(11)> HelloPhoenix.Repo.delete user
:ok
```
Let's see what the `all` function returns.

```console
iex(12)> HelloPhoenix.Repo.all HelloPhoenix.User
[]
```
Great, and now let's confirm that in the database.

```console
phoenix_demo=# select * from users;
 id | first_name | last_name | email | created_at | updated_at
----+------------+-----------+-------+------------+------------
(0 rows)
```

### Adding a Query Module

We've taken a look at Ecto's basic built-in query functions above, but what if we need something a little more complex? Ecto has a very expressive query building DSL. It also allows us to define query modules in which to define functions to perform specific queries. We'll explore both of these next.

For more complex queries, we have two options. If we have a one-off query, we might define a query using Ecto's dsl wherever we may be in the code, and have the `HelloPhoenix.Repo` execute our query right there. If, on the other hand, we might re-use our query, we can create a function in an Ecto query module to wrap the creation and execution of the query. That's the path we will persue here.

To begin with, let's start from a clean slate. We'll roll back and then migrate our database to reset both our tables and sequences.

```console
$ mix ecto.rollback HelloPhoenix.Repo
* running DOWN _build/dev/lib/hello_phoenix/priv/repo/migrations/20141125235524_initial_users_create.exs

$ mix ecto.migrate HelloPhoenix.Repo
* running UP _build/dev/lib/hello_phoenix/priv/repo/migrations/20141125235524_initial_users_create.exs
```
Now let's generate a migration to add a column to our `users` table.

```console
$ mix ecto.gen.migration HelloPhoenix.Repo add-active-column-to-users
* creating priv/repo/migrations
* creating priv/repo/migrations/20141130053817_add-active-column-to-users.exs
```
Then we add a new `active` field to our `HelloPhoenix.User` model with a boolean datatype and a default value of false.

```elixir
defmodule HelloPhoenix.User do
  use Ecto.Model

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :active, :boolean, default: false
    field :created_at, :datetime, default: Ecto.DateTime.local
    field :updated_at, :datetime, default: Ecto.DateTime.local
  end
end
```
With the field added to the model, we can fill out the migration we just created.

```elixir
defmodule :"Elixir.HelloPhoenix.Repo.Migrations.Add-active-column-to-users" do
  use Ecto.Migration

  def up do
    "ALTER TABLE users ADD COLUMN active boolean"
  end

  def down do
    "ALTER TABLE users DROP COLUMN active"
  end
end
```
Now we can run that migration to add the column to our `users` table.

```console
$ mix ecto.migrate HelloPhoenix.Repo
* running UP _build/dev/lib/hello_phoenix/priv/repo/migrations/20141130053817_add-active-column-to-users.exs
```

Let's see what it looks like in the database.

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
 active     | boolean                     |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
```
Great, `active` is there at the bottom.

Now let's add some users, both active and inactive. We begin with an iex session.

```console
$ iex -S mix
```
Then we create an active user.

```console
iex(1)> user = %HelloPhoenix.User{first_name: "Frodo", last_name: "Baggins", email: "frodo@example.com", active: true}
%HelloPhoenix.User{active: true,
 created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}, email: "frodo@example.com", first_name: "Frodo", id: nil,
 last_name: "Baggins",
 updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}}
```
And then we do the insert.

```console
iex(2)> HelloPhoenix.Repo.insert user
%HelloPhoenix.User{active: true,
 created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}, email: "frodo@example.com", first_name: "Frodo", id: 1,
 last_name: "Baggins",
 updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}}
```
Then we create an inactive user.

```console
iex(3)> user = %HelloPhoenix.User{first_name: "Bilbo", last_name: "Baggins", email: "bilbo@example.com"}
%HelloPhoenix.User{active: false,
 created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}, email: "bilbo@example.com", first_name: "Bilbo", id: nil,
 last_name: "Baggins",
 updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}}
```
And then we do the insert.

```console
iex(4)> HelloPhoenix.Repo.insert user
%HelloPhoenix.User{active: false,
 created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}, email: "bilbo@example.com", first_name: "Bilbo", id: 2,
 last_name: "Baggins",
 updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
  year: 2014}}
```
If we do a quick check in the database, we see that they are both there and that Ecto uses "t" and "f" to denote true and false.

```console
phoenix_demo=# select * from users;
 id | first_name | last_name |        email        |     created_at      |     updated_at      | active
----+------------+-----------+---------------------+---------------------+---------------------+--------
  1 | Frodo    | Baggins     | frodo@example.com   | 2014-11-29 21:52:15 | 2014-11-29 21:52:15 | t
  2 | Bilbo    | Baggins     | bilbo@example.com   | 2014-11-29 21:52:15 | 2014-11-29 21:52:15 | f
(2 rows)
```
Great, so our data is ready, and we can create a query module to define some specific query functions. Let's create this one at `web/models/user_query.ex` for now. We are naming this query module after our model, implying that these functions should only apply to the `HelloPhoenix.User` model. There is nothing in Ecto that enforces this, but as a project grows, this seems like a useful approach.

Since this is a very simple example, we're not going to create a separate `queries` directory, but if your project is large and complex, this might be an idea worth considering.

For our query module to work, we need to import `Ecto.Query`. Then all we need to do is define a function which creates and executes the query we want. In our case, we want to find all the active users. (Be sure to check out the [Ecto Query documentation](http://hexdocs.pm/ecto/Ecto.Query.html) for a full explanation of how to build queries in Ecto.)

```elixir
defmodule HelloPhoenix.UserQuery do
  import Ecto.Query

  def active do
    query = from users in HelloPhoenix.User,
            where: users.active == true,
            select: users
    HelloPhoenix.Repo.all query
  end
end
```
Now that we have our module and function defined, we can run it in our iex session. We would expect that our `active` function would return only the row for Frodo.

```console
iex(5)> HelloPhoenix.UserQuery.active
[%HelloPhoenix.User{active: true,
  created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}, email: "frodo@example.com", first_name: "Frodo", id: 1,
  last_name: "Baggins",
  updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}}]
```
That's exactly what happens.

Just to run a little sanity test, let's make sure that `HelloPhoenix.Repo.all` returns both of our user records.

```console
iex(6)> HelloPhoenix.Repo.all HelloPhoenix.User
[%HelloPhoenix.User{active: true,
  created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}, email: "frodo@example.com", first_name: "Frodo", id: 1,
  last_name: "Baggins",
  updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}},
 %HelloPhoenix.User{active: false,
  created_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}, email: "bilbo@example.com", first_name: "Bilbo", id: 2,
  last_name: "Baggins",
  updated_at: %Ecto.DateTime{day: 29, hour: 21, min: 52, month: 11, sec: 15,
   year: 2014}}]
```
It does indeed return both rows.

We've taken a tour of Ecto and how we might integrate it into our Phoenix project. The next section will show how we might use Ecto in the actions of a standard RESTful controller.

### Ecto in Controller Actions
