In the [Ecto Models Guide](http://www.phoenixframework.org/docs/ecto-models) we generated an HTML resource for users. This gave us a number of modules for free, including a user model and a user model test case. In this guide, we'll use the model and test case to work through the changes we made in the Ecto Models Guide in a test-driven way.

For those of us who haven't worked through the Ecto Models Guide, it's easy to catch up. Please see the "Generating an HTML Resource" section below.

Before we do anything else, let's run `mix test` to make sure our test suite runs cleanly.

```console
$ mix test
................

Finished in 0.6 seconds (0.5s on load, 0.1s on tests)
16 tests, 0 failures

Randomized with seed 638414
```

Great. We've got sixteen tests and they are all passing!

## Test Driving a Changeset

The focus of this guide is going to be on `test/models/user_test.exs`. Let's take a quick look to get familiar with it.

```elixir
defmodule HelloPhoenix.UserTest do
  use HelloPhoenix.ModelCase

  alias HelloPhoenix.User

  @valid_attrs %{bio: "some content", email: "some content", name: "some content", number_of_pets: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end
end
```

In the first line, we `use HelloPhoenix.ModelCase`, which is defined in `test/support/model_case.ex`. `HelloPhoenix.ModelCase` is responsible for importing and aliasing all the necessary modules for all of our model cases. `HelloPhoenix.ModelCase` will also run all of our model tests within a database transaction unless we've tagged an individual test case with `:async`.

> Note: We should not tag any model case that interacts with a database as `:async`. This may cause  erratic test results and possibly even deadlocks.

`HelloPhoenix.ModelCase` is also a place to define any helper functions we might need to test our models. We get an example function `errors_on/2` for free, and we'll see how that works shortly.

We alias our `HelloPhoenix.User` module so that we can refer to its structs as `%User{}` instead of `%HelloPhoenix.User{}`.

We also define module attributes for `@valid_attrs` and `@invalid_attrs` so they will be available to all our tests.

The generated test attributes we get from `HelloPhoenix.UserTest` are certainly usable as is, but let's change them to look just a bit more realistic. The only one that will really matter is `:email`, as that will need to have an `@` before we're done. The other changes are just cosmetic.

```elixir
defmodule HelloPhoenix.UserTest do
  use HelloPhoenix.ModelCase

  alias HelloPhoenix.User

  @valid_attrs %{bio: "my life", email: "pat@example.com", name: "Pat Example", number_of_pets: 4}
  @invalid_attrs %{}

  ...
end
```

We should change the `@valid_attrs` module attribute in `test/controllers/user_controller_test.exs` to match these as well for consistency.

```elixir
defmodule HelloPhoenix.UserControllerTest do
  use HelloPhoenix.ConnCase

  alias HelloPhoenix.User
  @valid_attrs %{bio: "my life", email: "pat@example.com", name: "Pat Example", number_of_pets: 4}
  @invalid_attrs %{}

  ...
end
```

If we run the tests again, all sixteen should still pass.

#### Number of Pets

While Phoenix generated our model with all of the fields required, the number of pets a user has is optional in our domain.

Let's write a new test to verify that.

To test this, we can delete the `:number_of_pets` key and value from the `@valid_attrs` map and make a `User` changeset from those new attributes. Then we can assert that the changeset is still valid.

```elixir
defmodule HelloPhoenix.UserTest do
  ...

  test "number_of_pets is not required" do
    changeset = User.changeset(%User{}, Map.delete(@valid_attrs, :number_of_pets))
    assert changeset.valid?
  end
end
```

Now, let's run the tests again.

```console
$ mix test
.............

  1) test number_of_pets is not required (HelloPhoenix.UserTest)
     test/models/user_test.exs:19
     Expected truthy, got false
     code: changeset.valid?()
     stacktrace:
       test/models/user_test.exs:21

...

Finished in 0.4 seconds (0.2s on load, 0.1s on tests)
17 tests, 1 failure

Randomized with seed 780208
```

It fails - which is exactly what it should do! We haven't written the code to make it pass yet. To  do that, we need to move the `number_of_pets` attribute from `@required_fields` to `@optional_fields` in `web/models/user.ex`.

```elixir
defmodule HelloPhoenix.User do
  use HelloPhoenix.Web, :model

  schema "users" do
    field :name, :string
    field :email, :string
    field :bio, :string
    field :number_of_pets, :integer

    timestamps
  end

  @required_fields ~w(name email bio)
  @optional_fields ~w(number_of_pets)

  ...
end
```

Now our tests are all passing again.

```console
$ mix test
.................

Finished in 0.3 seconds (0.2s on load, 0.09s on tests)
17 tests, 0 failures

Randomized with seed 963040
```

#### The Bio Attribute

In the Ecto Models Guide, we learned that the user's `:bio` attribute has two business requirements. The first is that it must be at least two characters long. Let's write a test for that using the same pattern we've just used.

First, we change the `:bio` attribute to have a value of a single character. Then we create a changeset with the new attributes and test its validity.

```elixir
defmodule HelloPhoenix.UserTest do
  ...

  test "bio must be at least two characters long" do
    attrs = %{@valid_attrs | bio: "I"}
    changeset = User.changeset(%User{}, attrs)
    refute changeset.valid?
  end
end
```

When we run the test, it fails, as we would expect.

```console
$ mix test
.....

  1) test bio must be at least two characters long (HelloPhoenix.UserTest)
     test/models/user_test.exs:24
     Expected false or nil, got true
     code: changeset.valid?()
     stacktrace:
       test/models/user_test.exs:27

............

Finished in 0.3 seconds (0.2s on load, 0.09s on tests)
18 tests, 1 failure

Randomized with seed 327779
```

Hmmm. Yes, this test behaved as we expected, but the error message doesn't seem to reflect our test. We're validating the length of the `:bio` attribute, and the message we get is "Expected false or nil, got true". There's no mention of our `:bio` attribute at all.

We can do better.

Let's change our test to get a better message while still testing the same behavior. We can leave the code to set the new `:bio` value in place. In the `assert`, however, we'll use the `errors_on/2` function we get from `ModelCase` to generate a list of errors, and check that the `:bio` attribute error is in that list.

```elixir
defmodule HelloPhoenix.UserTest do
  ...

  test "bio must be at least two characters long" do
    attrs = %{@valid_attrs | bio: "I"}
    assert {:bio, "should be at least 2 character(s)"} in errors_on(%User{}, attrs)
  end
end
```

> Note: `ModelCase.errors_on/2` returns a keyword list, and an individual element of a keyword list is a tuple.

When we run the tests again, we get a different message entirely.

```console
$ mix test
...............

  1) test bio must be at least two characters long (HelloPhoenix.UserTest)
     test/models/user_test.exs:24
     Assertion with in failed
     code: {:bio, "should be at least 2 character(s)"} in errors_on(%User{}, attrs)
     lhs:  {:bio,
            "should be at least 2 character(s)"}
     rhs:  []

..

Finished in 0.4 seconds (0.2s on load, 0.1s on tests)
18 tests, 1 failure

Randomized with seed 435902
```

This shows us the assertion we are testing - that our error is in the list of errors from the model's changeset.

```console
code: {:bio, "should be at least 2 character(s)"} in errors_on(%User{}, attrs)
```

We see that the left hand side of the expression evaluates to our error.

```console
lhs:  {:bio, "should be at least 2 character(s)"}
```

And we see that the right hand side of the expression evaluates to an empty list.

```console
rhs:  []
```

That list is empty because we don't yet validate the minimum length of the `:bio` attribute.

Our test has pointed the way. Now let's make it pass by adding that validation.

```elixir
defmodule HelloPhoenix.User do
  ...

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:bio, min: 2)
  end
end
```

When we run the tests again, they all pass.

```console
$ mix test
..................

Finished in 0.3 seconds (0.2s on load, 0.09s on tests)
18 tests, 0 failures

Randomized with seed 305958
```

The other business requirement for the `:bio` field is that it be a maximum of one hundred and forty characters. Let's write a test for that using the `errors_on/2` function again.

Before we actually write the test, how are we going to handle a string that long without making a mess? A new function in `HelloPhoenix.ModelCase` is perfect for this. We'll create a `long_string/1` function which will send us back a string of "a"'s as long as we tell it to be.

```elixir
defmodule HelloPhoenix.ModelCase do
  ...

  def long_string(length) do
    Enum.reduce (1..length), "", fn _, acc ->  acc <> "a" end
  end
end
```

We can now use `long_string/1` when changing the value of the `:bio` key in our `attrs`.

```elixir
defmodule HelloPhoenix.UserTest do
  ...

  test "bio must be at most 140 characters long" do
    attrs = %{@valid_attrs | bio: long_string(141)}
    assert {:bio, "should be at most 140 character(s)"} in errors_on(%User{}, attrs)
  end
end
```

When we run the test, it fails as we want it to.

```console
$ mix test
....

  1) test bio must be at most 140 characters long (HelloPhoenix.UserTest)
     test/models/user_test.exs:29
     Assertion with in failed
     code: {:bio, {:bio, "should be at most 140 character(s)"} in errors_on(%User{}, attrs)
     lhs:  {:bio,
            "should be at most 120 character(s)"}

..............

Finished in 0.3 seconds (0.2s on load, 0.1s on tests)
19 tests, 1 failure

Randomized with seed 593838
```

To make this test pass, we need to add a new validation for the maximum length of the `:bio` attribute.

```elixir
defmodule HelloPhoenix.User do
  ...

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:bio, min: 2)
    |> validate_length(:bio, max: 140)
  end
end
```

When we run the tests, they all pass.

```console
$ mix test
...................

Finished in 0.4 seconds (0.3s on load, 0.1s on tests)
19 tests, 0 failures

Randomized with seed 468975
```

#### The Email Attribute

We have one last attribute to validate. Currently, `:email` is just a string like any other. We'd like to make sure that it at least matches an "@". This is no substitute for an email confirmation, but it will weed out some invalid addresses before we even try.

This process will feel familiar by now. First, we change the value of the `:email` attribute to omit the "@". Then we write an assertion which uses `errors_on/2` to check for the correct validation error on the `:email` attribute.

```elixir
defmodule HelloPhoenix.UserTest do
  ...

  test "email must contain at least an @" do
    attrs = %{@valid_attrs | email: "fooexample.com"}
    assert {:email, "has invalid format"} in errors_on(%User{}, attrs)
  end
end
```

When we run the tests, it fails. We see that we're getting an empty list of errors back from `errors_on/2`.

```console
$ mix test
................

  1) test email must contain at least an @ (HelloPhoenix.UserTest)
     test/models/user_test.exs:34
     Assertion with in failed
     code: {:email, "has invalid format"} in errors_on(%User{}, attrs)
     lhs:  {:email, "has invalid format"}
     rhs:  []
     stacktrace:
       test/models/user_test.exs:36

...

Finished in 0.4 seconds (0.2s on load, 0.1s on tests)
20 tests, 1 failure

Randomized with seed 962127
```

Then we add the new validation to generate the error our test is looking for.

```elixir
defmodule HelloPhoenix.User do
  ...

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:bio, min: 2)
    |> validate_length(:bio, max: 140)
    |> validate_format(:email, ~r/@/)
  end
end
```

Now all the tests are passing again.

```console
$ mix test
....................

Finished in 0.3 seconds (0.2s on load, 0.09s on tests)
20 tests, 0 failures

Randomized with seed 330955
```

### Generating an HTML Resource

For this section, we're going to assume that we all have a PostgreSQL database installed on our system, and that we generated a default application - one in which Ecto and Postgrex are installed and configured automatically.

If this is not the case, please see the section on adding Ecto and Postgrex of the [Ecto Models Guide](http://www.phoenixframework.org/docs/ecto-models#section-adding-ecto-and-postgrex-as-dependencies) and join us when that's done.

Ok, once we're all configured properly, we need to run the `phoenix.gen.html` task with the list of attributes we have here.

```console
$ mix phoenix.gen.html User users name:string email:string bio:string number_of_pets:integer
* creating priv/repo/migrations/20150409213440_create_user.exs
* creating web/models/user.ex
* creating test/models/user_test.exs
* creating web/controllers/user_controller.ex
* creating web/templates/user/edit.html.eex
* creating web/templates/user/form.html.eex
* creating web/templates/user/index.html.eex
* creating web/templates/user/new.html.eex
* creating web/templates/user/show.html.eex
* creating web/views/user_view.ex
* creating test/controllers/user_controller_test.exs

Add the resource to your browser scope in web/router.ex:

    resources "/users", UserController

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Then we need to follow the instructions the task gives us and insert the `resources "/users", UserController` line in the router `web/router.ex`.

```elixir
defmodule HelloPhoenix.Router do
  ...

  scope "/", HelloPhoenix do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/users", UserController
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloPhoenix do
  #   pipe_through :api
  # end
end
```

With that done, we can create our database with `ecto.create`.

```console
$ mix ecto.create
The database for HelloPhoenix.Repo has been created.
```

Then we can migrate our database to create our `users` table with `ecto.migrate`.

```console
$ mix ecto.migrate

[info]  == Running HelloPhoenix.Repo.Migrations.CreateUser.change/0 forward

[info]  create table users

[info]  == Migrated in 0.0s
```

With that, we are ready to continue with the testing guide.
