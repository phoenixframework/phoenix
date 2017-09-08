# Testing Controllers

We're going to take a look at how we might test drive a controller which has endpoints for a JSON api.

Phoenix has a generator for creating a JSON resource which looks like this:

```console
mix phoenix.gen.json Stuff Thing things some_attr:string another_attr:string
```

Stuff is the context module name, Thing is the schema module name, things is the table name, and some_attr and another_attr are database columns on table things of type string. Don't run this command, we're going to explore test driving out a similar result to what a generator would give us.

### Set up
Let's create a `User` schema. Since schema creation is not in scope of this guide, we will use the generator.  If you aren't familiar, read [this section of the Mix guide](mix_tasks.html#phoenix-specific-mix-tasks).

```console
$ mix phx.gen.schema Accounts.User users name:string email:string
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170908031352_create_users.exs

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Now run migrations:

```console
$ mix ecto.migrate
[info] == Running Hello.Repo.Migrations.CreateUsers.change/0 forward
[info] create table users
[info] == Migrated in 0.0s
```

### Test driving

What we are going for is a controller with the standard CRUD actions. We'll start with our test since we're TDDing this. Create a `user_controller_test.exs` file in `test/hello_web/controllers`

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase, async: true

end
```

There are many ways to approach TDD. Here, we will think about each action we want to perform, and handle the "happy path" where things go as planned, and the error case where something goes wrong, if applicable.

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase, async: true

  test "index/2 responds with all Users"

  describe "create/2" do
    test "Creates, and responds with a newly created user if attributes are valid"
    test "Returns an error and does not create a user if attributes are invalid"
  end

  describe "show/2" do
    test "Responds with a newly created user if the user is found"
    test "Responds with a message indicating user not found"
  end

  describe "update/2" do
    test "Edits, and responds with the user if attributes are valid"
    test "Returns an error and does not edit the user if attributes are invalid"
  end

  test "delete/2 and responds with :ok if the user was deleted"

end
```

Here we have tests around the 5 controller CRUD actions we need to implement for a typical JSON API. In 2 cases, index and delete, we are only testing the happy path, because in our case they generally won't fail because of domain rules (or lack thereof). In practical application, our delete could fail easily once we have associated resources that cannot leave orphaned resources behind, or number of other situations. On index, we could have filtering and searching to test. Also, both could require authorization.

Create, show and update have more typical ways to fail because they need a way to find the resource, which could be non existent, or invalid data was supplied in the params. Since we have multiple tests for each of these endpoints, putting them in a `describe` block is good way to organize our tests.

Let's run the test:

```console
$ mix test test/controllers/user_controller_test.exs
```

We get 8 failures that say "Not implemented" which is good. Our tests don't have blocks yet.

Let's add our first test. We'll start with `index/2`.

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase, async: true

  alias Hello.{Repo, Accounts.User}

  test "index/2 responds with all Users" do
    users = [ User.changeset(%User{}, %{name: "John", email: "john@example.com"}),
              User.changeset(%User{}, %{name: "Jane", email: "jane@example.com"}) ]

    Enum.each(users, &Repo.insert!(&1))

    response = build_conn()
    |> get(user_path(build_conn(), :index))
    |> json_response(200)

    expected = %{
      "data" => [
        %{ "name" => "John", "email" => "john@example.com" },
        %{ "name" => "Jane", "email" => "jane@example.com" }
      ]
    }

    assert response == expected
  end
```
Let's take a look at what's going on here. We build our users, and use the `get` function to make a `GET` request to our `UserController` index action, which is piped into `json_response/2` along with the expected HTTP status code. This will return the JSON from the response body, when everything is wired up properly. We represent the JSON we want the controller action to return with the variable `expected`, and assert that the `response` and `expected` are the same.

Our expected data is a JSON response with a top level key of `"data"` containing an array of users that have `"name"` and `"email"` properties.

When we run the test we get an error that we have no `user_path` function.

In our router, we'll add a resource for `User` in our API pipe:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    resources "/users", HelloWeb.UserController
  end

  ...
```

We should get a new error now. Running the test informs us we don't have a `UserController`. Let's add it, along with the `index/2` action we're testing. Our test description has us returning all users:

```elixir
defmodule HelloWeb.UserController do
  use HelloWeb, :controller

  alias Hello.{Accounts.User, Repo}

  def index(conn, _params) do
    users = Repo.all(User)
    render conn, "index.json", users: users
  end

end
```

When we run the test again, our failing test tells us we have no view. Let's add it. Our test specifies a JSON format with a top key of `"data"`, containing an array of users with attributes `"name"` and `"email"`.

```elixir
defmodule HelloWeb.UserView do
  use HelloWeb, :view

  def render("index.json", %{users: users}) do
    %{data: render_many(users, HelloWeb.UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{name: user.name, email: user.email}
  end

end
```

And with that, our test passes when we run it.

We'll also cover the `show/2` action here so we can see how to handle an error case.

Our show tests currently look like this:

```elixir
  describe "show/2" do
    test "Responds with a newly created user if the user is found"
    test "Responds with a message indicating user not found"
  end
```

Run this test only by running the following command: (if your show tests don't start on line 32, change the line number accordingly)

```console
$ mix test test/hello_web/controllers/user_controller_test.exs:32
```

Our first `show/2` test result is, as expected, not implemented.
Let's build a test around what we think a successful `show/2` should look like.

```elixir
test "Responds with a newly created user if the user is found" do
  user = User.changeset(%User{}, %{name: "John", email: "john@example.com"})
  |> Repo.insert!

  response = build_conn()
  |> get(user_path(build_conn(), :show, user.id))
  |> json_response(200)

  expected = %{ "data" => %{ "name" => "John", "email" => "john@example.com" } }

  assert response == expected
end
```

This is very similar to our `index/2` test, except `show/2` requires a user id, and our data is a single JSON object instead of an array.

When we run our test tells us we need a `show/2` action.

```elixir
defmodule HelloWeb.UserController do
  use HelloWeb, :controller

  alias Hello.{Accounts.User, Repo}

  def index(conn, _params) do
    users = Repo.all(User)
    render conn, "index.json", users: users
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(User, id) do
      user -> render conn, "show.json", user: user
    end
  end
end
```

You'll notice we only handle the case where we successfully find a user. When we TDD we only want to write enough code to make the test pass. We'll add more code when we get to the error handling test for `show/2`.

Running the test tells us we need a `render/2` function that can pattern match on `"show.json"`:

```elixir
defmodule HelloWeb.UserView do
  use HelloWeb, :view

  def render("index.json", %{users: users}) do
    %{data: render_many(users, HelloWeb.UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, HelloWeb.UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{name: user.name, email: user.email}
  end

end
```

When we run the test again, it passes.

The last item we'll cover is the case where we don't find a user in `show/2`.

Try this one on your own and see what you come up with. One possible solution will be given below.

Walking through our TDD steps, we add a test that supplies a non existent user id to `user_path` which returns a 404 status and an error message:

```elixir
test "Responds with a message indicating user not found" do
  response = build_conn()
  |> get(user_path(build_conn(), :show, 300))
  |> json_response(404)

  expected = %{ "error" => "User not found." }

  assert response == expected
end
```

We want a HTTP code of 404 to notify the requester that this resource was not found, as well as an accompanying error message.

Our controller action:

```elixir
def show(conn, %{"id" => id}) do
  case Repo.get(User, id) do
    nil -> conn |> put_status(404) |> render("error.json")
    user -> render conn, "show.json", user: user
  end
end
```

And our view:

```elixir
def render("error.json", _assigns) do
  %{error: "User not found."}
end
```

With those implemented, our tests pass.

The rest of the controller is left to you to implement as practice. Happy testing!
