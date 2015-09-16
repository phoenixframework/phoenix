Sometimes we inherit a legacy database on top of which we need to build a new application. We can't control how these databases were created, and changing them to meet our current needs can be both difficult and expensive.

Ecto expects each table to have an auto-incremented integer for a primary key. What if our legacy database requires a string as the primary key instead? No problem. We can create our models with a custom primary key, and Ecto will work just the same as if we had an integer.

> Note: While Ecto allows us to do this, it's not the natural path Ecto wants to take. Allowing Ecto to use an auto-incremented integer is definitely the right way to go for new applications.

> Also, we chose this example for simplicity. `name` might not be the best choice for a primary key.

Let's say that we need a JSON resource that stores rows of team athletes. Each athlete has a name, a position they play on the field, and the number of their jersey. The database that will back this resource requires that each table have a string for a primary key.

We can generate that resource like this.

```console
$ mix phoenix.gen.json Player players name:string position:string number:integer
* creating priv/repo/migrations/20150908003815_create_player.exs
* creating web/models/player.ex
* creating test/models/player_test.exs
* creating web/controllers/player_controller.ex
* creating web/views/player_view.ex
* creating test/controllers/player_controller_test.exs
* creating web/views/changeset_view.ex

Add the resource to your api scope in web/router.ex:

    resources "/players", PlayerController

and then update your repository by running migrations:

    $ mix ecto.migrate
```

The first thing we need to do is add the resources route to the `api` scope in the router.

```elixir
. . .
scope "/api", HelloPhoenix do
  pipe_through :api

  resources "/players", PlayerController
end
. . .
```

Now we'll need to make a few quick changes to the generated files.

Let's take a look at the migration first, `priv/repo/migrations/20150908003815_create_player.exs`. We'll need to do two things. The first is to pass in a second argument - `primary_key: false` to the `table/2` function so that it won't create a primary_key. Then we'll need to pass `primary_key: true` to the `add/3` function for the name field to signal that it will be the primary_key instead.

```elixir
defmodule HelloPhoenix.Repo.Migrations.CreatePlayer do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :name, :string, primary_key: true
      add :position, :string
      add :number, :integer

      timestamps
    end
  end
end
```

Let's move on to `web/models/player.ex` next. We'll need to add a module attribute `@primary_key {:name, :string, []}` describing our primary key as a string. Then we'll need to tell Phoenix how to convert our data structure to an ID that is used in the routes: `@derive {Phoenix.Param, key: :name}`. We'll also need to remove the `field :name, :string` line because this is our new primary key. If this seems unusual, recall that the schema doesn't list the `id` field in models where `id` is the primary key.

```elixir
defmodule HelloPhoenix.Player do
  use HelloPhoenix.Web, :model

  @primary_key {:name, :string, []}
  @derive {Phoenix.Param, key: :name}
  schema "players" do
    field :position, :string
    field :number, :integer

    timestamps
  end
  . . .
```

There's just one more thing we'll need to do, and that's remove the reference to `id: player.id,` in the `def render("player.json", %{player: player})` function body.

```elixir
defmodule HelloPhoenix.PlayerView do
  use HelloPhoenix.Web, :view

  . . .

  def render("player.json", %{player: player}) do
    %{name: player.name,
      position: player.position,
      number: player.number}
  end
end
```

With all of that taken care of, let's run our migration.

```console
$mix ecto.migrate
```

The resulting `players` table will look like this:

```sql
hello_phoenix_dev=# \d players
                Table "public.players"
   Column    |            Type             | Modifiers
-------------+-----------------------------+-----------
 name        | character varying(255)      | not null
 position    | character varying(255)      |
 number      | integer                     |
 inserted_at | timestamp without time zone | not null
 updated_at  | timestamp without time zone | not null
Indexes:
    "players_pkey" PRIMARY KEY, btree (name)
```

Now we have a model with the primary key `name` that we can query for with `Repo.get!/2`. We can also use it in our routes instead of an integer id - `localhost:4000/players/iguberman`.
