# Testing Contexts

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Introduction to Testing guide](testing.html).

> **Requirement**: This guide expects that you have gone through the [Contexts guides](contexts.html).

At the end of the Introduction to Testing guide, we generated an HTML resource for posts using the following command:

```console
$ mix phx.gen.html Blog Post posts title body:text
```

This gave us a number of modules for free, including a Blog context and a Post schema, alongside their respective test files. As we have learned in the Context guide, the Blog context is simply a module with functions to a particular area of our business domain, while Post schema maps to a particular table in our database.

In this guide, we are going to explore the tests generated for our contexts and schemas. Before we do anything else, let's run `mix test` to make sure our test suite runs cleanly.

```console
$ mix test
................

Finished in 0.6 seconds
21 tests, 0 failures

Randomized with seed 638414
```

Great. We've got twenty-one tests and they are all passing!

## Testing posts

If you open up `test/hello/blog_test.exs`, you will see a file with the following:

```elixir
defmodule Hello.BlogTest do
  use Hello.DataCase

  alias Hello.Blog

  describe "posts" do
    alias Hello.Blog.Post

    import Hello.BlogFixtures

    @invalid_attrs %{body: nil, title: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Blog.list_posts() == [post]
    end

    ...
```

As the top of the file we import `Hello.DataCase`, which as we will see soon, it is similar to `HelloWeb.ConnCase`. While `HelloWeb.ConnCase` sets up helpers for working with connections, which is useful when testing controllers and views, `Hello.DataCase` provides functionality for working with contexts and schemas.

Next, we define an alias, so we can refer to `Hello.Blog` simply as `Blog`.

Then we start a `describe "posts"` block. A `describe` block is a feature in ExUnit that allows us to group similar tests. The reason why we have grouped all post related tests together is because contexts in Phoenix are capable of grouping multiple schemas together. For example, if we ran this command:

```console
$ mix phx.gen.html Blog Comment comments post_id:references:posts body:text
```

We will get a bunch of new functions in the `Hello.Blog` context, plus a whole new `describe "comments"` block in our test file.

The tests defined for our context are very straight-forward. They call the functions in our context and assert on their results. As you can see, some of those tests even create entries in the database:

```elixir
test "create_post/1 with valid data creates a post" do
  valid_attrs = %{body: "some body", title: "some title"}

  assert {:ok, %Post{} = post} = Blog.create_post(valid_attrs)
  assert post.body == "some body"
  assert post.title == "some title"
end
```

At this point, you may wonder: how can Phoenix make sure the data created in one of the tests do not affect other tests? We are glad you asked. To answer this question, let's talk about the `DataCase`.

## The DataCase

If you open up `test/support/data_case.ex`, you will find the following:

```elixir
defmodule Hello.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Hello.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Hello.DataCase
    end
  end

  setup tags do
    Hello.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Hello.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    ...
  end
end
```

`Hello.DataCase` is another `ExUnit.CaseTemplate`. In the `using` block, we can see all of the aliases and imports `DataCase` brings into our tests. The `setup` chunk for `DataCase` is very similar to the one from `ConnCase`. As we can see, most of the `setup` block revolves around setting up a SQL Sandbox.

The SQL Sandbox is precisely what allows our tests to write to the database without affecting any of the other tests. In a nutshell, at the beginning of every test, we start a transaction in the database. When the test is over, we automatically rollback the transaction, effectively erasing all of the data created in the test.

Furthermore, the SQL Sandbox allows multiple tests to run concurrently, even if they talk to the database. This feature is provided for PostgreSQL databases and it can be used to further speed up your contexts and controllers tests by adding a `async: true` flag when using them:

```elixir
use Hello.DataCase, async: true
```

There are some considerations you need to have in mind when running asynchronous tests with the sandbox, so please refer to the [`Ecto.Adapters.SQL.Sandbox`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html) for more information.

Finally, at the end of the `DataCase` module we can find a function named `errors_on` with some examples of how to use it. This function is used for testing any validation we may want to add to our schemas. Let's give it a try by adding our own validations and then testing them.

## Testing schemas

When we generate our HTML Post resource, Phoenix generated a Blog context and a Post schema. It generated a test file for the context, but no test file for the schema. However, this doesn't mean we don't need to test the schema, it just means we did not have to test the schema so far.

You may be wondering then: when do we test the context directly and when do we test the schema directly? The answer to this question is the same answer to the question of when do we add code to a context and when do we add it to the schema?

The general guideline is to keep all side-effect free code in the schema. In other words, if you are simply working with data structures, schemas and changesets, put it in the schema. The context will typically have the code that creates and updates schemas and then write them to a database or an API.

We'll be adding additional validations to the schema module, so that's a great opportunity to write some schema specific tests. Open up `lib/hello/blog/post.ex` and add the following validation to `def changeset`:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> validate_required([:title, :body])
  |> validate_length(:title, min: 2)
end
```

The new validation says the title needs to have at least 2 characters. Let's write a test for this. Create a new file at `test/hello/blog/post_test.exs` with this:

```elixir
defmodule Hello.Blog.PostTest do
  use Hello.DataCase, async: true
  alias Hello.Blog.Post

  test "title must be at least two characters long" do
    changeset = Post.changeset(%Post{}, %{title: "I"})
    assert %{title: ["should be at least 2 character(s)"]} = errors_on(changeset)
  end
end
```

And that's it. As our business domain grows, we have well-defined places to test our contexts and schemas.
