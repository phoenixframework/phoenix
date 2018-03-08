# Testing Controllers

We're going to take a look at how we might test drive a controller which has endpoints for a JSON api.

Phoenix has a generator for creating a JSON resource which looks like this:

```console
$ mix phx.gen.json  AllTheThings Thing things some_attr:string another_attr:string
```

In this command, AllTheThings is the context; Thing is the schema; things is the plural name of the schema (which is used as the table name). Then `some_attr` and `another_attr` are the database columns on table `things` of type string.

However, *don't* actually run this command. Instead, we're going to explore test driving out a similar result to what a generator would give us.

### Set up

If you haven't already done so, first create a blank project by running:

```console
$ mix phx.new hello
```

Change into the newly-created `hello` directory, configure your database in `config/dev.exs` and then run:

```console
$ mix ecto.create
```

If you have any questions about this process, now is a good time to jump over to the [Up and Running Guide](up_and_running.html).

Let's create an `Accounts` context for this example. Since context creation is not in scope of this guide, we will use the generator. If you aren't familiar, read [this section of the Mix guide](phoenix_mix_tasks.html#phoenix-specific-mix-tasks) and [the Contexts Guide](contexts.html#content).

```console
$ mix phx.gen.context Accounts User users name:string email:string:unique password:string

* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170913155721_create_users.exs
* creating lib/hello/accounts/accounts.ex
* injecting lib/hello/accounts/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Ordinarily we would spend time tweaking the generated migration file (`priv/repo/migrations/<datetime>_create_users.exs`) to add things like non-null constraints and so on, but we don't need to make any changes for this example, so we can just run the migration:

```console
$ mix ecto.migrate
Compiling 2 files (.ex)
Generated hello app
[info] == Running Hello.Repo.Migrations.CreateUsers.change/0 forward
[info] create table users
[info] create index users_email_index
[info] == Migrated in 0.0s
```

As a final check before we start developing, we can run `mix test` and make sure that all is well.

```console
$ mix test
```

All of the tests should pass, but sometimes the database isn't configured properly in `config/test.exs`, or some other issue crops up. It is best to correct these issues now, *before* we complicate things with deliberately breaking tests!

### Test driving

What we are going for is a controller with the standard CRUD actions. We'll start with our test since we're TDDing this. Create a `user_controller_test.exs` file in `test/hello_web/controllers`

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

end
```

There are many ways to approach TDD. Here, we will think about each action we want to perform, and handle the "happy path" where things go as planned, and the error case where something goes wrong, if applicable.

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

  test "index/2 responds with all Users"

  describe "create/2" do
    test "Creates, and responds with a newly created user if attributes are valid"
    test "Returns an error and does not create a user if attributes are invalid"
  end

  describe "show/2" do
    test "Responds with user info if the user is found"
    test "Responds with a message indicating user not found"
  end

  describe "update/2" do
    test "Edits, and responds with the user if attributes are valid"
    test "Returns an error and does not edit the user if attributes are invalid"
  end

  test "delete/2 and responds with :ok if the user was deleted"

end
```

Here we have tests around the 5 controller CRUD actions we need to implement for a typical JSON API. At the top of the module we are using the module `HelloWeb.ConnCase`, which provides connections to our test repository. Then we define the 8 tests. In 2 cases, index and delete, we are only testing the happy path, because in our case they generally won't fail because of domain rules (or lack thereof). In practical application, our delete could fail easily once we have associated resources that cannot leave orphaned resources behind, or number of other situations. On index, we could have filtering and searching to test. Also, both could require authorization.

Create, show and update have more typical ways to fail because they need a way to find the resource, which could be non existent, or invalid data was supplied in the params. Since we have multiple tests for each of these endpoints, putting them in a `describe` block is good way to organize our tests.

Let's run the test:

```console
$ mix test test/hello_web/controllers/user_controller_test.exs
```

We get 8 failures that say "Not implemented" which is good. Our tests don't have blocks yet.

### The first test

Let's add our first test. We'll start with `index/2`.

```elixir
defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

  alias Hello.Accounts

  test "index/2 responds with all Users", %{conn: conn} do

    users = [%{name: "John", email: "john@example.com", password: "john pass"},
             %{name: "Jane", email: "jane@example.com", password: "jane pass"}]

    # create users local to this database connection and test
    [{:ok, user1},{:ok, user2}] = Enum.map(users, &Accounts.create_user(&1))

    response =
      conn
      |> get(user_path(conn, :index))
      |> json_response(200)

    expected = %{
      "data" => [
        %{ "name" => user1.name, "email" => user1.email },
        %{ "name" => user2.name, "email" => user2.email }
      ]
    }

    assert response == expected
  end
```

Let's take a look at what's going on here. First we alias `Hello.Accounts`, the context module that provides us with our repository manipulation functions. When we use the `HelloWeb.ConnCase` module, it sets things up such that each connection is wrapped in a transaction, *and* all of the database interactions inside of the test use the same database connection and transaction. This module also sets up a `conn` attribute in our ExUnit context, using `Phoenix.ConnCase/build_conn/0`. We then pattern match this to use it in each test case. For details, take a look at the file `test/support/conn_case.ex`, as well as the [Ecto documentation for SQL.Sandbox](https://hexdocs.pm/ecto/Ecto.Adapters.SQL.Sandbox.html). We could put a `build_conn/0` call inside of each test, but it is cleaner to use a setup block to do it.

The index test then hooks into the context to extract the contents of the `:conn` key. We then create two users using the `Hello.Accounts.create_user/1` function. Again, note that this function accesses the test repo, but even though we don't pass the `conn` variable to the call, it still uses the same connection and puts these new users inside the same database transaction. Next the `conn` is piped to a `get` function to make a `GET` request to our `UserController` index action, which is in turn piped into `json_response/2` along with the expected HTTP status code. This will return the JSON from the response body, when everything is wired up properly. We represent the JSON we want the controller action to return with the variable `expected`, and assert that the `response` and `expected` are the same.

Our expected data is a JSON response with a top level key of `"data"` containing an array of users that have `"name"` and `"email"` properties that should match the users created before making the request. Also, we do not want the users' "password" properties to show up in our JSON response.

When we run the test we get an error that we have no `user_path` function.

In our router, we'll uncomment the `api` scope at the bottom of the auto-generated file, and then use the resources macro to generate the routes for the "/users" path. Because we aren't going to be generating forms to create and update users, we add the `except: [:new, :edit]` to skip those endpoints.

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
  end

  scope "/", HelloWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", HelloWeb do
    pipe_through :api
    resources "/users", UserController, except: [:new, :edit]
  end
end
```

Before running the test again, check out our new paths by running `mix phx.routes`. You should see six new "/api" routes in addition to the default page controller route:

```console
$ mix phx.routes
Compiling 6 files (.ex)
page_path  GET     /               HelloWeb.PageController :index
user_path  GET     /api/users      HelloWeb.UserController :index
user_path  GET     /api/users/:id  HelloWeb.UserController :show
user_path  POST    /api/users      HelloWeb.UserController :create
user_path  PATCH   /api/users/:id  HelloWeb.UserController :update
           PUT     /api/users/:id  HelloWeb.UserController :update
user_path  DELETE  /api/users/:id  HelloWeb.UserController :delete
```

We should get a new error now. Running the test informs us we don't have a `HelloWeb.UserController`. Let's create that controller by opening the file `lib/hello_web/controllers/user_controller.ex` and adding the `index/2` action we're testing. Our test description has us returning all users:

```elixir
defmodule HelloWeb.UserController do
  use HelloWeb, :controller
  alias Hello.Accounts

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

end
```

When we run the test again, our failing test tells us the module `HelloWeb.UserView` is not available. Let's add it by creating the file `lib/hello_web/views/user_view.ex`. Our test specifies a JSON format with a top key of `"data"`, containing an array of users with attributes `"name"` and `"email"`.

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

The view module for the index uses the `render_many/4` function. According to the [documentation](https://hexdocs.pm/phoenix/Phoenix.View.html#render_many/4), using `render_many/4` is "roughly equivalent" to using `Enum.map/2`, and in fact `Enum.map` is called under the hood. The main difference between `render_many/4` and directly calling `Enum.map/2` is that the former benefits from library-quality error checking, properly handling missing values, and so on. `render_many/4` also has an `:as` option that can used so that the key in the assigns map can be renamed. By default, this is inferred from the module name (`:user` in this case), but it can be changed if necessary to fit the render function being used.

And with that, our test passes when we run it.

### Testing the show action

We'll also cover the `show/2` action here so we can see how to handle an error case.

Our show tests currently look like this:

```elixir
  describe "show/2" do
    test "Responds with user info if the user is found"
    test "Responds with a message indicating user not found"
  end
```

Run this test only by running the following command: (if your show tests don't start on line 34, change the line number accordingly)

```console
$ mix test test/hello_web/controllers/user_controller_test.exs:34
```

Our first `show/2` test result is, as expected, not implemented. Let's build a test around what we think a successful `show/2` should look like.

```elixir
test "Responds with user info if the user is found", %{conn: conn} do
  {:ok, user} = Accounts.create_user(%{name: "John", email: "john@example.com", password: "john pass"})

  response =
    conn
    |> get(user_path(conn, :show, user.id))
    |> json_response(200)

  expected = %{"data" => %{"email" => user.email, "name" => user.name}}

  assert response == expected
end
```

This is fine, but it can be refactored slightly. Notice that both this test and the index test need users in the database. Instead of creating these users over and over again, we can instead call another `setup/1` function to populate the database with users on an as-needed basis. To do this, first create a private function at the bottom of the test module as follows:

```elixir
defp create_user(_) do
  {:ok, user} = Accounts.create_user(@create_attrs)
  {:ok, user: user}
end
```
Next define `@create_attrs` as a custom attribute for the module at the top, as follows.

```elixir
alias Hello.Accounts

@create_attrs %{name: "John", email: "john@example.com", password: "john pass"}
```


Finally, invoke the function using a second `setup/1` call inside of the `describe` block:

```elixir
describe "show/2" do
  setup [:create_user]
  test "Responds with user info if the user is found", %{conn: conn, user: user} do

    response =
      conn
      |> get(user_path(conn, :show, user.id))
      |> json_response(200)

    expected = %{"data" => %{"email" => user.email, "name" => user.name}}

    assert response == expected
  end
  test "Responds with a message indicating user not found"
end
```

The functions called by `setup` take an ExUnit context (not to be confused with the contexts we are describing throughout this guide) and allow us to add additional fields when we return. In this case, `create_user` doesn't care about the existing context (hence the underscore parameter), and adds a new user to the ExUnit context under the key `user:`  by returning `{:ok, user: user}`. The test can then access both the database connection and this new user from the ExUnit context.

Finally, let's change our `index/2` test to also use the new `create_user` function. The index test doesn't *really* need two users, after all. The revised `index/2` test should look like this:

```elixir
  describe "index/2" do
    setup [:create_user]
    test "index/2 responds with all Users", %{conn: conn, user: user} do

      response =
        conn
        |> get(user_path(conn, :index))
        |> json_response(200)

      expected = %{"data" => [%{"name" => user.name, "email" => user.email}]}

      assert response == expected
    end
  end
```

The biggest change here is that we now wrapped the old test inside of another `describe` block so that we have somewhere to put the `setup/2` call for the index test. We are now accessing the user from the ExUnit context, and expecting just a single user from the `index/2` test results, not two.

The `index/2` test should still pass, but the `show/2` test will error with a message that we need a `HelloWeb.UserController.show/2` action. Let's add that to the UserController module next.

```elixir
defmodule HelloWeb.UserController do
  use HelloWeb, :controller
  alias Hello.Accounts

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.json", user: user)
  end

end
```

You might notice the exclamation point in the `get_user!/1` function. This convention means that this function will throw an error if the requested user is not found. You'll also notice that we aren't properly handling the possibility of a thrown error here. When we TDD we only want to write enough code to make the test pass. We'll add more code when we get to the error handling test for `show/2`.

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

Notice the "show.json" rendering path uses `render_one/4` instead of `render_many/4` because it is only rendering a single user, not a list.

When we run the test again, it passes.

### Show when the user is not found

The last item we'll cover is the case where we don't find a user in `show/2`.

Try this one on your own and see what you come up with. One possible solution will be given below.

Walking through our TDD steps, we add a test that supplies a non-existent user id to `user_path` which returns a 404 status and an error message. One interesting problem here is how we might define a "non-existent" id. We could just pick a large integer, but who's to say some future test won't generate thousands of test users and break our test? Instead of going bigger, we can also go the other way. Database ids tend to start at 1 and increase forever. Negative numbers are perfectly valid integers, and yet never used for database ids. So we'll pick -1 as our "unobtainable" user id, which *should* always fail.

```elixir
test "Responds with a message indicating user not found", %{conn:  conn} do
  conn = get(conn, user_path(conn, :show, -1))

  assert text_response(conn, 404) =~ "User not found"
end
```

We want a HTTP status code of 404 to notify the requester that this resource was not found, as well as an accompanying error message. Notice that we use [`text_response/2`](https://hexdocs.pm/phoenix/Phoenix.ConnTest.html#text_response/2) instead of [`json_response/2`](https://hexdocs.pm/phoenix/Phoenix.ConnTest.html#json_response/2) to assert that the status code is 404 and the response body matches the accompanying error message. You can run this test now to see what happens. You should see that an `Ecto.NoResultsError` is thrown, because there is no such user in the database.

Our controller action needs to handle the error thrown by Ecto. We have two choices here. By default, this will be handled by the [phoenix_ecto](https://github.com/phoenixframework/phoenix_ecto) library, returning a 404. However if we want to show a custom error message, we can create a new `get_user/1` function that does not throw an Ecto error. For this example, we'll take the second path and implement a new `get_user/1` function in the file `lib/hello/accounts/accounts.ex`, just before the `get_user!/1` function:

```elixir
@doc """
Gets a single `%User{}` from the data store where the primary key matches the
given id.

Returns `nil` if no result was found.

## Examples

    iex> get_user(123)
    %User{}

    iex> get_user(456)
    nil

"""
def get_user(id), do: Repo.get(User, id)
```

This function is just a thin wrapper around `Ecto.Repo.get/3`, and like that function will return either a `%User{}` if the user is found, or `nil` if not. Next change the `show/2` function to use the non-throwing version, and handle the two possible result cases.

```elixir
def show(conn, %{"id" => id}) do
  case Accounts.get_user(id) do
    nil ->
      conn
      |> put_status(:not_found)
      |> text("User not found")

    user ->
      render(conn, "show.json", user: user)
  end
end
```

The first branch of the case statement handles the `nil` result case. First, we use the [`put_status/2`](https://hexdocs.pm/plug/Plug.Conn.html#put_status/2) function from `Plug.Conn` to set the desired error status. The complete list of allowed codes can be found in the [Plug.Conn.Status documentation](https://hexdocs.pm/plug/Plug.Conn.Status.html), where we can see that `:not_found` corresponds to our desired "404" status. We then return a text response using [`text/2`](https://hexdocs.pm/phoenix/Phoenix.Controller.html#text/2).

The second branch of the case statement handles the "happy path" we've already covered. Phoenix also allows us to only implement the "happy path" in our action and use `Phoenix.Controller.action_fallback/1`. This is useful for centralizing your error handling code. You may wish to refactor the show action to use action_fallback as covered in the "Action Fallback" section of the [controllers guide](controllers.html#action-fallback).

With those implemented, our tests pass. 

The rest of the controller is left for you to implement as practice. If you are not sure where to begin, it is worth using the Phoenix JSON generator and seeing what tests are automatically generated for you.

Happy testing!
