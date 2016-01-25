When creating an app, it's important that we're able to seed our database with some initial data (e.g., for early development work or pre-launch testing purposes).

Fortunately, Phoenix already provides us with a convention for seeding data. By default Phoenix generates a script file for each app at `priv/repo/seeds.exs`, which we can use to use to populate our database/repository.

Also note that in order to seed data as in the example below you should have alrady generated and run the related migration (i.e., Link migration, controller, model, etc.) and updated your `router.ex`, as described in the [Ecto Models Guide](http://www.phoenixframework.org/docs/ecto-models) (if you haven't completed that Guide yet, should should do so before proceeding further).

So in order to seed data, we simply need to add a script to `seeds.exs` that uses our database/repository to directly add the data we want. As you can see from the comments that Phoenix generated for us in `seeds.exs` file, we should follow this pattern:

```elixir
  <%= application_module %>.Repo.insert!(%<%= application_module %>.SomeModel{})
```
For example, if we were creating an app called Linker and wanted to seed a Link table in our database/repository with with a series of links, we could simply add the following script to our `seeds.exs` file:

```elixir
  ...
  alias Linker.Repo
  alias Linker.Link

  Repo.insert! %Link{
    title: "Phoenix Framework",
    url: "http://www.phoenixframework.org/"
  }
  
  Repo.insert! %Link{
    title: "Elixir",
    url: "http://elixir-lang.org/"
  }
  
  Repo.insert! %Link{
    title: "Erlang",
    url: "https://www.erlang.org/"
  }
  ...
```
With this script, we've set up some aliases and then progressed through a list of our Links which will each be written to the database/repo when we run the `seeds.exs` file with mix run:

```elixir
  mix run priv/repo/seeds.exs
```
Note that if we wanted to delete/scrub all prior data that we seeded in the Link table, we could also include `Repo.delete_all Link` in your script immediate above `Repo.insert!` 

#### Models are Initialized

Conveniently, when following this convention, Phoenix makes sure that our models are appropriately initialized; and as long as we use the bang functions (e.g.,  `insert!`, `update!`, etc.), they will also fail if something goes wrong.

This is helpful, since it means that if we make a programming error (e.g., attempting to add a duplicate entry to a table where the field is required to be unique), the data in our database won’t lose its integrity since to the database will refuse to execute the query and Ecto will throw an exception, such as:

```elixir
  ** (Ecto.ConstraintError) constraint error when attempting to insert model:
```
Which will be followed by a description of the error/violated constraints.

If desired for development purposes, we can also modify our script to do error checking before executing the bang functions (e.g., checking for duplicates), so as to prevent them from failing.