# Testing Controllers

We're going to take a look at how we might test drive a controller which has endpoints for a JSON api.

Phoenix has a generator for creating a JSON resource which looks like this:

```console
$ mix phx.gen.json  AllTheThings Thing things some_attr:string another_attr:string
```

In this command, AllTheThings is the Context; Thing is the Schema;
things is the plural name of the schema (which is used as the table
name).  Then `some_attr` and `another_attr` are the database columns on
table `things` of type string.

However, *don't* actually run this command.  Instead, we're going to
explore test driving out a similar result to what a generator would
give us.

### Set up

If you haven't already done so, first create a blank project by running

```console
$ mix phx.new hello -y
```

Change into the newly-created `hello` directory, configure
your database in `config/dev.exs` and then run

```console
$ mix ecto.create
```

If you have any questions about this process, now is a good time to
jump over to the [Up and Running Guide](up_and_running.html).


Let's create an `Accounts` context for this example.
Since context creation is not in scope of this guide, we will use the
generator.  If you aren't familiar, read [this section of the Mix
guide](phoenix_mix_tasks.html#phoenix-specific-mix-tasks) and [the Contexts
Guide](contexts.html#content).

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

Ordinarily we would spend time tweaking the generated migration file
(`priv/repo/migrations/<datetime>_create_users.exs`) to add things
like non-null constraints and so on, but we don't care about that for
this example.  Just run the migration:

```console
$ mix ecto.migrate
Compiling 2 files (.ex)
Generated hello app
[info] == Running Hello.Repo.Migrations.CreateUsers.change/0 forward
[info] create table users
[info] create index users_email_index
[info] == Migrated in 0.0s
```

As a final check before we start developing, we run `mix test` and
make sure that all is well.

```console
$ mix test
```

All of the tests should pass, but sometimes the database isn't
specified properly in `config/test.exs`, or some other issue crops
up.  It is best to correct these issues now, *before* we complicate
things with deliberately breaking tests!

### Test driving

What we are going for is a controller with the standard CRUD actions. We'll start with our test since we're TDDing this. Create a `user_controller_test.exs` file in `test/hello_web/controllers`

```elixir
# test/hello_web/controllers/user_controller_test.exs

defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

end
```

There are many ways to approach TDD. Here, we will think about each action we want to perform, and handle the "happy path" where things go as planned, and the error case where something goes wrong, if applicable.

```elixir
# test/hello_web/controllers/user_controller_test.exs

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

Here we have tests around the 5 controller CRUD actions we need to implement for a typical JSON API. In 2 cases, index and delete, we are only testing the happy path, because in our case they generally won't fail because of domain rules (or lack thereof). In practical application, our delete could fail easily once we have associated resources that cannot leave orphaned resources behind, or number of other situations. On index, we could have filtering and searching to test. Also, both could require authorization.

Create, show and update have more typical ways to fail because they need a way to find the resource, which could be non existent, or invalid data was supplied in the params. Since we have multiple tests for each of these endpoints, putting them in a `describe` block is good way to organize our tests.

Let's run the test:

```console
$ mix test test/hello_web/controllers/user_controller_test.exs
```

We get 8 failures that say "Not implemented" which is good. Our tests don't have blocks yet.

### The first test

Let's add our first test. We'll start with `index/2`.

```elixir
# test/hello_web/controllers/user_controller_test.exs

defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

  alias Hello.Accounts

  @user1_attrs %{email: "grobblefruit@example.org", name: "John", password: "surf and skate"}
  @user2_attrs %{email: "varibiggles@example.org",  name: "Jane",  password: "coffee and beer"}

  # setup creates users for all tests, and generates the conn
  setup do
    {:ok, user1} = Accounts.create_user(@user1_attrs)
    {:ok, user2} = Accounts.create_user(@user2_attrs)
    conn = build_conn()
    # results are loaded into the context passed to each test
    {:ok, conn: conn, user1: user1, user2: user2}
  end

  test "index/2 responds with all Users", %{conn: conn, user1: user1, user2: user2} do

    response = conn
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

Let's take a look at what's going on here. First, some attributes for
two valid users are defined, and then a [`setup/1`
block](https://hexdocs.pm/ex_unit/1.5.1/ExUnit.Callbacks.html#content)
is used to create those users before each test.  The `setup/1` block also
creates a `conn` variable to be used in each test.  Then `conn`,
`user1`, and `user2` are returned as a map from the `setup` block, and are
merged into the context that is passed to each test.

The index test then hooks into the context to extract the contents of
the `conn:`, `user1:`, and `user2` keys.  The `conn` is piped to a `get` function
to make a `GET` request to our `UserController` index action, which is
in turn piped into `json_response/2` along with the expected HTTP status code. This will return the JSON from the response body, when everything is wired up properly. We represent the JSON we want the controller action to return with the variable `expected`, and assert that the `response` and `expected` are the same.


Our expected data is a JSON response with a top level key of `"data"`
containing an array of users that have `"name"` and `"email"`
properties that should match those of the `userN` objects created by
the `setup/1` function.

When we run the test we get an error that we have no `user_path` function.

In our router, we'll uncomment the `api` scope at the bottom of the
auto-generated file, and then add a resource for `User` in the API.
Because we aren't going to be generating forms to create and update
users, we add the `except: [:new, :edit]` to skip those endpoints.


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

Before running the test again, check out our new paths by running `mix
phx.routes`.  You should see six new "/api" routes in addition to the default
page controller route:

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



We should get a new error now. Running the test informs us we don't have a `HelloWeb.UserController`. Let's add it, along with the `index/2` action we're testing. Our test description has us returning all users:

```elixir
# lib/hello_web/controllers/user_controller.ex

defmodule HelloWeb.UserController do
  use HelloWeb, :controller
  alias Hello.Accounts

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", data: users)
  end

end
```

When we run the test again, our failing test tells us module `HelloWeb.UserView` is not available. Let's add it. Our test specifies a JSON format with a top key of `"data"`, containing an array of users with attributes `"name"` and `"email"`.

```elixir
# lib/hello_web/views/user_view.ex

defmodule HelloWeb.UserView do
  use HelloWeb, :view

  def render("index.json", %{data: users}) do
    %{data:
      render_many( users, HelloWeb.UserView, "user.json", as: :data)
      }
  end

  def render("user.json", %{data: user}) do
    %{
      name: user.name,
      email: user.email
      # skipping password, inserted_at, and updated_at
    }
  end
end
```

The view module for the index uses the `render_many/4` function.
According to the
[documentation](https://hexdocs.pm/phoenix/Phoenix.View.html#render_many/4),
using `render_many/4` is "roughly equivalent" to using `Enum.map/2`,
and in fact `Enum.map` is called under the hood.  The main difference
is that by using `render_many/4` instead of directly calling
`Enum.map/2` is that the former benefits from library-quality error
checking, properly handling missing values, and so on.

And with that, our test passes when we run it.

### Time for the show

We'll also cover the `show/2` action here so we can see how to handle an error case.

Our show tests currently look like this:

```elixir
  describe "show/2" do
    test "Responds with user info if the user is found"
    test "Responds with a message indicating user not found"
  end
```

Run this test only by running the following command: (if your show tests don't start on line 41, change the line number accordingly)

```console
$ mix test test/hello_web/controllers/user_controller_test.exs:41
```

Our first `show/2` test result is, as expected, not implemented.
Let's build a test around what we think a successful `show/2` should look like.

```elixir
# test/hello_phoenix_web/controllers/user_controller_test.exs line 41 (or so)

test "Responds with user info if the user is found", %{conn: conn, user1: user} do
  response = conn
  |> get(user_path(conn, :show, user.id))
  |> json_response(200)

  expected = %{
    "data" =>
    %{ "email" => user.email, "name" => user.name }

  }

  assert response == expected
end
```

This is very similar to our `index/2` test, except `show/2` requires a
user id, and our data is a single JSON object instead of an
array. Notice that because we only need one user for this test, we're
only grabbing `user1:` from the context, and mapping it to `user`.


When we run our test tells us we need a `HelloWeb.UserController.show/2` action.

```elixir
# lib/hello_web/controllers/user_controller.ex

defmodule HelloWeb.UserController do
  use HelloWeb, :controller
  alias Hello.Accounts

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", data: users)
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render conn, "show.json", data: user
  end

end
```

You might notice the exclamation point in the `get_user!/1` function.
This convention means that this function will throw an error if the
requested user is not found.  You'll also notice that we aren't
properly handling the possibility of a thrown error here. When we TDD we only want to write enough code to make the test pass. We'll add more code when we get to the error handling test for `show/2`.

Running the test tells us we need a `render/2` function that can pattern match on `"show.json"`:

```elixir
defmodule HelloWeb.UserView do
  use HelloWeb, :view

  def render("index.json", %{data: users}) do
    %{data:
      render_many( users, HelloWeb.UserView, "user.json", as: :data)
      }
  end

  def render("show.json", %{data: user}) do
    %{data:
      render_one( user, HelloWeb.UserView, "user.json", as: :data)
      }
  end

  def render("user.json", %{data: user}) do
    %{
      name: user.name,
      email: user.email
      # skipping password, inserted_at, and updated_at
    }
  end
end
```

Notice the "show.json" rendering path uses `render_one/4` instead of
`render_many/4` because it is only rendering a single user, not a list.


When we run the test again, it passes.

### No show

The last item we'll cover is the case where we don't find a user in `show/2`.

Try this one on your own and see what you come up with. One possible solution will be given below.

Walking through our TDD steps, we add a test that supplies a
non-existent user id to `user_path` which returns a 404 status and an
error message.  One interesting problem here is how we might define a
"non-existent" id.  We could just pick a large integer, but who's to
say some future test won't generate thousands of test users and break
our test?  Instead of going bigger, we can also go the other way.
Database ids tend to start at 1 and increase forever.  Negative
numbers are perfectly valid integers, and yet never used for database
ids.  So we'll pick -1 as our "unobtainable" user id, which *should*
always fail.


```elixir
# test/hello_web/controllers/user_controller_test.exs line 55 (or so)

test "Responds with a message indicating user not found", %{conn:  conn} do
  response = conn
  |> get(user_path(conn, :show, -1 ))
  |> json_response(404)

  expected = %{
    "errors" => "Resource not found"
  }

  assert response == expected
end
```

We want a HTTP code of 404 to notify the requester that this resource was not found, as well as an accompanying error message.

Our controller action now needs to handle the error thrown by Ecto:

```elixir
# lib/hello_web/controllers/user_controller.ex, line 10 or so

  def show(conn, %{"id" => id}) do
    try do
      user = Accounts.get_user!(id)
      render conn, "show.json", data: user
    catch
      :error, message ->
        conn
        |> put_status(:not_found)
        |> render( HelloWeb.ErrorView, "400.json", reason: message )
    end
  end
```

In the `catch` block, there are two important things going on.
First we use the
[`put_status/2`](https://hexdocs.pm/plug/Plug.Conn.html#put_status/2)
function from `Plug.Conn` to set the desired error status.  The complete list of allowed codes can be found in the
[Plug.Conn.Status
documentation](https://hexdocs.pm/plug/Plug.Conn.Status.html), where
we can see that `:not_found` corresponds to our desired "404" status.

Second, we've redirected the view to the `ErrorView` module.  If you
open that file up, you'll see a few rendering helpers for HTML,
output, but none for JSON.  We need to add a render function for
"400.json" as follows:

```
# lib/hello_web/views/error_view.ex

defmodule HelloWeb.ErrorView do
  use HelloWeb, :view

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  def render("400.json", %{reason: reason}) do
    message = case reason do
                %Ecto.NoResultsError{} -> "Resource not found"
                _ -> "I'm afraid I can't do that, Dave"
              end
    %{errors: message}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
```

In the "400.json" render function, we only expect the `%Ecto.NoResultsError{}`
so far, so we only set that message.  As other errors crop up in our
TDD development, we can add additional error messages.

With those implemented, our tests pass.

### Two down, six (or more) to go

The rest of the controller is left for you to implement as practice. To
help you on your way, below is a more fully fleshed out test file.  Of
course there are lots of edge cases and error conditions that are *not*
covered, but it should get you started.  Then maybe use the Phoenix
JSON generator and see what tests are automatically generated for you.

```
# test/hello_web/controllers/user_controller_test.exs

defmodule HelloWeb.UserControllerTest do
  use HelloWeb.ConnCase

  alias Hello.Accounts

  @user1_attrs %{email: "grobblefruit@example.org", name: "John", password: "surf and skate"}
  @user2_attrs %{email: "varibiggles@example.org",  name: "Jane", password: "coffee and beer"}
  @user3_attrs %{email: "scrumptious@example.org",  name: "Pat",  password: "busy work is my jam"}
  @update_attrs %{email: "falada@horsehead.org", name: "goose girl", password: "covered in tar and feathers"}
  @bad_attrs %{email: "", name: "", password: ""}

  # setup creates users for all tests, and generates the conn
  setup do
    {:ok, user1} = Accounts.create_user(@user1_attrs)
    {:ok, user2} = Accounts.create_user(@user2_attrs)
    conn = build_conn()
    # results are loaded into the context passed to each test
    {:ok, conn: conn, user1: user1, user2: user2}
  end

  test "index/2 responds with all Users", %{conn: conn, user1: user1, user2: user2} do

    response = conn
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

  describe "create/2" do
    test "Creates, and responds with a newly created user if attributes are valid", %{conn: conn} do
      response = conn
      |> post( user_path(conn, :create), data: %{ attributes: @user3_attrs } )
      |> json_response(201)
      assert( response["data"] == %{"email"=> @user3_attrs.email,
                                   "name" => @user3_attrs.name}
      )

    end

    test "Cannot create a user with a duplicate email", %{conn: conn, user1: user} do
      response = conn
      |> post( user_path(conn, :create), data: %{ attributes: %{"email" => user.email,
                                                               "name" => @user3_attrs.name,
                                                               "password" => @user3_attrs.password} } )
      |> json_response(422)
      assert( response["errors"] == %{"email"=>  ["has already been taken"]} )

    end

    test "Returns an error and does not create a user if attributes are invalid", %{conn: conn} do
      response = conn
      |> post( user_path(conn, :create), data: %{ attributes: @bad_attrs })
      |> json_response(422)
      assert( response["errors"] == %{
        "name" => ["can't be blank"],
        "email" => ["can't be blank"],
        "password" => ["can't be blank"] }
        )
    end
  end

  describe "show/2" do
    test "Responds with user info if the user is found", %{conn: conn, user1: user} do
      response = conn
      |> get(user_path(conn, :show, user.id))
      |> json_response(200)

      expected = %{
        "data" =>
        %{ "email" => user.email, "name" => user.name }

      }

      assert response == expected
    end

    test "Responds with a message indicating user not found", %{conn: conn} do
      response = conn
      |> get(user_path(conn, :show, -1 ))
      |> json_response(404)

      expected = %{
        "errors" => "Resource not found"
      }

      assert response == expected
    end
  end

  describe "update/2" do
    setup do
      {:ok, user3} = Accounts.create_user(@user3_attrs)
      {:ok, user3: user3}
    end
    test "Edits, and responds with the user if attributes are valid", %{conn: conn, user3: user} do
      response = conn
      |> put(user_path(conn, :update, user.id ), data: %{ attributes: @update_attrs } )
      |> json_response(200)

      expected = %{
        "data" =>
        %{ "email" => @update_attrs.email, "name" => @update_attrs.name }
      }
      assert response == expected
    end
    test "Returns the unmodified user if attributes object is empty", %{conn: conn, user2: user} do

      response = conn
      |>put( user_path(conn, :update, user.id ), data: %{ attributes: %{} } )
      |> json_response(200)

      expected = %{
        "data" =>
        %{ "email" => user.email, "name" => user.name }
      }
      assert response == expected

    end
    test "Returns an error and does not edit the user if attributes are invalid", %{conn: conn, user3: user} do

      response = conn
        |> put( user_path(conn, :update, user.id ), data: %{ attributes: @bad_attrs })
        |> json_response(422)

      assert response["errors"] == %{
        "name" => ["can't be blank"],
        "email" => ["can't be blank"]
      }
      # by the way, will crash if attributes are set to nil (not a hash)
    end
  end

  describe "delete/2" do
    setup do
      {:ok, user3} = Accounts.create_user(@user3_attrs)
      {:ok, user3: user3}
    end

    test "delete/2 and responds with :ok if the user was deleted", %{conn: conn, user3: user} do
      r = conn
      |> delete( user_path(conn, :delete, user.id) )

      assert response(r, 204)
      response = conn
      |> get( user_path(conn, :show, user.id) )
      |> json_response(404)

      assert response["errors"] == "Resource not found"

    end
    test "delete/2 throws if user doesn't exist", %{conn: conn, user3: user} do
      r = conn
      |> delete( user_path(conn, :delete, user.id) )

      assert response(r, 204)

      response = conn
      |> delete( user_path(conn, :delete, user.id) )
      |> json_response(404)

      assert response["errors"] == "Resource not found"

    end
  end

end
```


Happy testing!
