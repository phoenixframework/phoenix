# Testing Schemas

In the [Ecto Guide](ecto.html) we generated an HTML resource for users. This gave us a number of modules for free, including a user schema and a user schema test case. In this guide, we'll use the schema and test case to work through the changes we made in the Ecto Guide in a test-driven way.

For those of us who haven't worked through the Ecto Guide, it's easy to catch up. Please see the "Generating an HTML Resource" section below.

Before we do anything else, let's run `mix test` to make sure our test suite runs cleanly.

```console
$ mix test
................

Finished in 0.6 seconds
20 tests, 0 failures

Randomized with seed 638414
```

Great. We've got twenty tests and they are all passing!

## Test Driving a Changeset

We'll be adding additional validations to the schema module, so let's create `test/hello/accounts/user_test.exs` with this content:

```elixir
defmodule Hello.Accounts.UserTest do
  use Hello.DataCase

  alias Hello.Accounts.User

  @valid_attrs %{bio: "my life", email: "pat@example.com", name: "Pat Example", number_of_pets: 4}
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

In the first line, we `use Hello.DataCase`, which is defined in `test/support/data_case.ex`. `Hello.DataCase` is responsible for importing and aliasing all the necessary modules for all of our schema cases. `Hello.DataCase` will also run all of our schema tests within a database transaction unless we've tagged an individual test case with `:async`.

> Note: We should not tag any schema case that interacts with a database as `:async`. This may cause  erratic test results and possibly even deadlocks.

`Hello.DataCase` is also a place to define any helper functions we might need to test our schemas. We get an example function `errors_on/1` for free, and we'll see how that works shortly.

We alias our `Hello.Accounts.User` module so that we can refer to its structs as `%User{}` instead of `%Hello.Accounts.User{}`.

We also define module attributes for `@valid_attrs` and `@invalid_attrs` so they will be available to all our tests.

If we run the tests again, we've got 22, and they should all pass.

#### Number of Pets

While Phoenix generated our model with all of the fields required, the number of pets a user has is optional in our domain.

Let's write a new test to verify that.

To test this, we can delete the `:number_of_pets` key and value from the `@valid_attrs` map and make a `User` changeset from those new attributes. Then we can assert that the changeset is still valid.

```elixir
defmodule Hello.Accounts.UserTest do
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
....................

  1) test number_of_pets is not required (Hello.Accounts.UserTest)
     test/hello/accounts/user_test.exs:19
     Expected truthy, got false
     code: assert changeset.valid?()
     stacktrace:
       test/hello/accounts/user_test.exs:21: (test)
..

Finished in 0.4 seconds
23 tests, 1 failure

Randomized with seed 780208
```

It fails - which is exactly what it should do! We haven't written the code to make it pass yet. To do that, we need to remove the `:number_of_pets` attribute from our `validate_required/3` function in `lib/hello_web/models/user.ex`.

```elixir
defmodule Hello.Accounts.User do
  ...

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :email, :bio, :number_of_pets])
    |> validate_required([:name, :email, :bio])
  end
end
```

Now our tests are all passing again.

```console
$ mix test
.......................

Finished in 0.3 seconds
23 tests, 0 failures

Randomized with seed 963040
```

#### The Bio Attribute

In the Ecto Guide, we learned that the user's `:bio` attribute has two business requirements. The first is that it must be at least two characters long. Let's write a test for that using the same pattern we've just used.

First, we change the `:bio` attribute to have a value of a single character. Then we create a changeset with the new attributes and test its validity.

```elixir
defmodule Hello.Accounts.UserTest do
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
...................

  1) test bio must be at least two characters long (Hello.Accounts.UserTest)
     test/hello/accounts/user_test.exs:24
     Expected false or nil, got true
     code: refute changeset.valid?()
     stacktrace:
       test/hello/accounts/user_test.exs:27: (test)

....

Finished in 0.3 seconds
24 tests, 1 failure

Randomized with seed 327779
```

Hmmm. Yes, this test behaved as we expected, but the error message doesn't seem to reflect our test. We're validating the length of the `:bio` attribute, and the message we get is "Expected false or nil, got true". There's no mention of our `:bio` attribute at all.

We can do better.

Let's change our test to get a better message while still testing the same behavior. We can leave the code to set the new `:bio` value in place. In the `assert`, however, we'll use the `errors_on/1` function we get from `DataCase` to generate a map of errors, and check that the `:bio` attribute error is in that map.

```elixir
defmodule Hello.Accounts.UserTest do
  ...

  test "bio must be at least two characters long" do
    attrs = %{@valid_attrs | bio: "I"}
    changeset = User.changeset(%User{}, attrs)
    assert %{bio: ["should be at least 2 character(s)"]} = errors_on(changeset)
  end
end
```

When we run the tests again, we get a different message entirely.

```console
$ mix test
...................

  1) test bio must be at least two characters long (Hello.Accounts.UserTest)
     test/hello/accounts/user_test.exs:24
     match (=) failed
     code:  assert %{bio: ["should be at least 2 character(s)"]} = errors_on(changeset)
     right: %{}
     stacktrace:
       test/hello/accounts/user_test.exs:27: (test)

....

Finished in 0.4 seconds
24 tests, 1 failure

Randomized with seed 435902
```

This shows us the assertion we are testing - that our error is in the map of errors from the model's changeset.

```console
code:  assert %{bio: ["should be at least 2 character(s)"]} = errors_on(changeset)
```

And we see that the right hand side of the expression evaluates to an empty map.

```console
rhs:  %{}
```

That map is empty because we don't yet validate the minimum length of the `:bio` attribute.

Our test has pointed the way. Now let's make it pass by adding that validation.

```elixir
defmodule Hello.Accounts.User do
  ...

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :email, :bio, :number_of_pets])
    |> validate_required([:name, :email, :bio])
    |> validate_length(:bio, min: 2)
  end
end
```

When we run the tests again, they all pass.

```console
$ mix test
........................

Finished in 0.2 seconds
24 tests, 0 failures

Randomized with seed 305958
```

The other business requirement for the `:bio` field is that it be a maximum of one hundred and forty characters. Let's write a test for that using the `errors_on/1` function again.

We'll use String.duplicate/2 to produce n-long "a" string here.

```elixir
defmodule Hello.Accounts.UserTest do
  ...

  test "bio must be at most 140 characters long" do
    attrs = %{@valid_attrs | bio: String.duplicate("a", 141)}
    changeset = User.changeset(%User{}, attrs)
    assert %{bio: ["should be at most 140 character(s)"]} = errors_on(changeset)
  end
end
```

When we run the test, it fails as we want it to.

```console
$ mix test
.......................

  1) test bio must be at most 140 characters long (Hello.Accounts.UserTest)
     test/hello/accounts/user_test.exs:30
     match (=) failed
     code:  assert %{bio: ["should be at most 140 character(s)"]} = errors_on(changeset)
     right: %{}
     stacktrace:
       test/hello/accounts/user_test.exs:33: (test)

.

Finished in 0.3 seconds
25 tests, 1 failure

Randomized with seed 593838
```

To make this test pass, we need to add a maximum to the length validation of the `:bio` attribute.

```elixir
defmodule Hello.Accounts.User do
  ...

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :email, :bio, :number_of_pets])
    |> validate_required([:name, :email, :bio])
    |> validate_length(:bio, min: 2, max: 140)
  end
end
```

When we run the tests, they all pass.

```console
$ mix test
.........................

Finished in 0.4 seconds
25 tests, 0 failures

Randomized with seed 468975
```

#### The Email Attribute

We have one last attribute to validate. Currently, `:email` is just a string like any other. We'd like to make sure that it at least matches an "@". This is no substitute for an email confirmation, but it will weed out some invalid addresses before we even try.

This process will feel familiar by now. First, we change the value of the `:email` attribute to omit the "@". Then we write an assertion which uses `errors_on/1` to check for the correct validation error on the `:email` attribute.

```elixir
defmodule Hello.Accounts.UserTest do
  ...

  test "email must contain at least an @" do
    attrs = %{@valid_attrs | email: "fooexample.com"}
    changeset = User.changeset(%User{}, attrs)
    assert %{email: ["has invalid format"]} = errors_on(changeset)
  end
end
```

When we run the tests, it fails. We see that we're getting an empty map of errors back from `errors_on/1`.

```console
$ mix test
.......................

  1) test email must contain at least an @ (Hello.Accounts.UserTest)
     test/hello/accounts/user_test.exs:36
     match (=) failed
     code:  assert %{email: ["has invalid format"]} = errors_on(changeset)
     right: %{}
     stacktrace:
       test/hello/accounts/user_test.exs:39: (test)

..

Finished in 0.4 seconds
26 tests, 1 failure

Randomized with seed 962127
```

Then we add the new validation to generate the error our test is looking for.

```elixir
defmodule Hello.Accounts.User do
  ...

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :email, :bio, :number_of_pets])
    |> validate_required([:name, :email, :bio])
    |> validate_length(:bio, min: 2, max: 140)
    |> validate_format(:email, ~r/@/)
  end
end
```

Now the schema tests are passing again, but other tests are now failing, if you haven't touched the generated context & controller tests. Here's one failure (but because tests are run in random order, you might see a different failure first):

```console
$ mix test
....

  1) test update user renders errors when data is invalid (HelloWeb.UserControllerTest)
     test/hello_web/controllers/user_controller_test.exs:66
     ** (MatchError) no match of right hand side value: {:error, #Ecto.Changeset<action: :insert, changes: %{bio: "some bio", email: "some email", name: "some name", number_of_pets: 42}, errors: [email: {"has invalid format", [validation: :format]}], data: #Hello.Accounts.User<>, valid?: false>}
     stacktrace:
       test/hello_web/controllers/user_controller_test.exs:11: HelloWeb.UserControllerTest.fixture/1
       test/hello_web/controllers/user_controller_test.exs:85: HelloWeb.UserControllerTest.create_user/1
       test/hello_web/controllers/user_controller_test.exs:1: HelloWeb.UserControllerTest.__ex_unit__/2
  ...

Finished in 0.1 seconds
26 tests, 12 failures

Randomized with seed 825065
```

We can fix these tests by editing the module attributes in the failing test files - first, in `test/hello_web/controllers/user_controller_test.exs`, add an "@" to the `:email` values in `@valid_attrs` and `@update_attrs`:

```elixir
defmodule HelloWeb.UserControllerTest do
  ...
  @create_attrs %{bio: "some bio", email: "some@email", name: "some name", number_of_pets: 42}
  @update_attrs %{bio: "some updated bio", email: "some updated@email", name: "some updated name", number_of_pets: 43}
  @invalid_attrs %{bio: nil, email: nil, name: nil, number_of_pets: nil}
  ...
```

This will fix all of the HelloWeb.UserControllerTest failures.

Make the same changes to the module attributes in `test/hello/accounts/accounts_test.exs`:

```elixir
defmodule Hello.AccountsTest do
    ...
    @valid_attrs %{bio: "some bio", email: "some@email", name: "some name", number_of_pets: 42}
    @update_attrs %{bio: "some updated bio", email: "updated@email", name: "some updated name", number_of_pets: 43}
    @invalid_attrs %{bio: nil, email: nil, name: nil, number_of_pets: nil}
    ...
```

This will fix all but two of the failures - to fix those last two, we'll need to fix the values those tests are comparing:

```elixir
defmodule Hello.AccountsTest do
  ...
  test "create_user/1 with valid data creates a user" do
    assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
    assert user.bio == "some bio"
    assert user.email == "some@email"
    assert user.name == "some name"
    assert user.number_of_pets == 42
  end

  ...

  test "update_user/2 with valid data updates the user" do
    user = user_fixture()
    assert {:ok, user} = Accounts.update_user(user, @update_attrs)
    assert %User{} = user
    assert user.bio == "some updated bio"
    assert user.email == "some updated@email"
    assert user.name == "some updated name"
    assert user.number_of_pets == 43
  end

end
```

Now all the tests pass again:

```console
$ mix test
..........................

Finished in 0.2 seconds
26 tests, 0 failures

Randomized with seed 330955
```

### Generating an HTML Resource

For this section, we're going to assume that we all have a PostgreSQL database installed on our system, and that we generated a default application - one in which Ecto and Postgrex are installed and configured automatically.

If this is not the case, please see the section on adding Ecto and Postgrex of the [Ecto Guide](ecto.html) and join us when that's done.

Ok, once we're all configured properly, we need to run the `phx.gen.html` task with the list of attributes we have here.

```console
$ mix phx.gen.html Accounts User users name:string email:string \
bio:string number_of_pets:integer
* creating lib/hello_web/controllers/user_controller.ex
* creating lib/hello_web/templates/user/edit.html.eex
* creating lib/hello_web/templates/user/form.html.eex
* creating lib/hello_web/templates/user/index.html.eex
* creating lib/hello_web/templates/user/new.html.eex
* creating lib/hello_web/templates/user/show.html.eex
* creating lib/hello_web/views/user_view.ex
* creating test/hello_web/controllers/user_controller_test.exs
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170906212909_create_users.exs
* creating lib/hello/accounts/accounts.ex
* injecting lib/hello/accounts/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs

Add the resource to your browser scope in web/router.ex:

    resources "/users", UserController

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Then we need to follow the instructions the task gives us and insert the `resources "/users", UserController` line in the router `lib/hello_web/router.ex`.

```elixir
defmodule HelloWeb.Router do
  ...

  scope "/", HelloWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/users", UserController
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloWeb do
  #   pipe_through :api
  # end
end
```

With that done, we can create our database with `ecto.create`.

```console
$ mix ecto.create
The database for Hello.Repo has been created.
```

Then we can migrate our database to create our `users` table with `ecto.migrate`.

```console
$ mix ecto.migrate

[info]  == Running Hello.Repo.Migrations.CreateUser.change/0 forward

[info]  create table users

[info]  == Migrated in 0.0s
```

With that, we are ready to continue with the testing guide.
