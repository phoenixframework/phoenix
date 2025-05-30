# Testing Controllers

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Introduction to Testing guide](testing.html).

At the end of the Introduction to Testing guide, we generated an HTML resource for posts using the following command:

```console
$ mix phx.gen.html Blog Post posts title body:text
```

This gave us a number of modules for free, including a PostController and the associated tests. We are going to explore those tests to learn more about testing controllers in general. At the end of the guide, we will generate a JSON resource, and explore how our API tests look like.

## HTML controller tests

If you open up `test/hello_web/controllers/post_controller_test.exs`, you will find the following:

```elixir
defmodule HelloWeb.PostControllerTest do
  use HelloWeb.ConnCase

  import Hello.BlogFixtures

  @create_attrs %{body: "some body", title: "some title"}
  @update_attrs %{body: "some updated body", title: "some updated title"}
  @invalid_attrs %{body: nil, title: nil}
  
  describe "index" do
    test "lists all posts", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "Listing Posts"
    end
  end

  ...
```

Similar to the `PageControllerTest` that ships with our application, this controller tests uses `use HelloWeb.ConnCase` to setup the testing structure. Then, as usual, it defines some aliases, some module attributes to use throughout testing, and then it starts a series of `describe` blocks, each of them to test a different controller action.

### The index action

The first describe block is for the `index` action. The action itself is implemented like this in `lib/hello_web/controllers/post_controller.ex`:

```elixir
def index(conn, _params) do
  posts = Blog.list_posts()
  render(conn, :index, posts: posts)
end
```

It gets all posts and renders the "index.html" template. The template can be found in `lib/hello_web/controllers/post_html/index.html.heex`.

The test looks like this:

```elixir
describe "index" do
  test "lists all posts", %{conn: conn} do
    conn = get(conn, ~p"/posts")
    assert html_response(conn, 200) =~ "Listing Posts"
  end
end
```

The test for the `index` page is quite straight-forward. It uses the `get/2` helper to make a request to the `"/posts"` page, which is verified against our router in the test thanks to `~p`, then we assert we got a successful HTML response and match on its contents.

### The create action

The next test we will look at is the one for the `create` action. The `create` action implementation is this:

```elixir
def create(conn, %{"post" => post_params}) do
  case Blog.create_post(post_params) do
    {:ok, post} ->
      conn
      |> put_flash(:info, "Post created successfully.")
      |> redirect(to: ~p"/posts/#{post}")

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :new, changeset: changeset)
  end
end
```

Since there are two possible outcomes for the `create`, we will have at least two tests:

```elixir
describe "create post" do
  test "redirects to show when data is valid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @create_attrs)

    assert %{id: id} = redirected_params(conn)
    assert redirected_to(conn) == ~p"/posts/#{id}"

    conn = get(conn, ~p"/posts/#{id}")
    assert html_response(conn, 200) =~ "Post #{id}"
  end

  test "renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @invalid_attrs)
    assert html_response(conn, 200) =~ "New Post"
  end
end
```

The first test starts with a `post/2` request. That's because once the form in the `/posts/new` page is submitted, it becomes a POST request to the create action. Because we have supplied valid attributes, the post should have been successfully created and we should have redirected to the show action of the new post. This new page will have an address like `/posts/ID`, where ID is the identifier of the post in the database.

We then use `redirected_params(conn)` to get the ID of the post and then match that we indeed redirected to the show action. Finally, we do a `get` request to the page we redirected to, allowing us to verify that the post was indeed created.

For the second test, we simply test the failure scenario. If any invalid attribute is given, it should re-render the "New Post" page.

One common question is: how many failure scenarios do you test at the controller level? For example, in the [Testing Contexts](testing_contexts.html) guide, we introduced a validation to the `title` field of the post:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> validate_required([:title, :body])
  |> validate_length(:title, min: 2)
end
```

In other words, creating a post can fail for the following reasons:

  * the title is missing
  * the body is missing
  * the title is present but is less than 2 characters

Should we test all of these possible outcomes in our controller tests?

The answer is no. All of the different rules and outcomes should be verified in your context and schema tests. The controller works as the integration layer. In the controller tests we simply want to verify, in broad strokes, that we handle both success and failure scenarios.

The test for `update` follows a similar structure as `create`, so let's skip to the `delete` test.

### The delete action

The `delete` action looks like this:

```elixir
def delete(conn, %{"id" => id}) do
  post = Blog.get_post!(id)
  {:ok, _post} = Blog.delete_post(post)

  conn
  |> put_flash(:info, "Post deleted successfully.")
  |> redirect(to: ~p"/posts")
end
```

The test is written like this:

```elixir
  describe "delete post" do
    setup [:create_post]

    test "deletes chosen post", %{conn: conn, post: post} do
      conn = delete(conn, ~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/posts"

      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/#{post}")
      end
    end
  end

  defp create_post(_) do
    post = post_fixture()
    %{post: post}
  end
```

First of all, `setup` is used to declare that the `create_post` function should run before every test in this `describe` block. The `create_post` function simply creates a post and stores it in the test metadata. This allows us to, in the first line of the test, match on both the post and the connection:

```elixir
test "deletes chosen post", %{conn: conn, post: post} do
```

The test uses `delete/2` to delete the post and then asserts that we redirected to the index page. Finally, we check that it is no longer possible to access the show page of the deleted post:

```elixir
assert_error_sent 404, fn ->
  get(conn, ~p"/posts/#{post}")
end
```

`assert_error_sent` is a testing helper provided by `Phoenix.ConnTest`. In this case, it verifies that:

  1. An exception was raised
  2. The exception has a status code equivalent to 404 (which stands for Not Found)

This pretty much mimics how Phoenix handles exceptions. For example, when we access `/posts/12345` where `12345` is an ID that does not exist, we will invoke our `show` action:

```elixir
def show(conn, %{"id" => id}) do
  post = Blog.get_post!(id)
  render(conn, :show, post: post)
end
```

When an unknown post ID is given to `Blog.get_post!/1`, it raises an `Ecto.NotFoundError`. If your application raises any exception during a web request, Phoenix translates those requests into proper HTTP response codes. In this case, 404.

We could, for example, have written this test as:

```elixir
assert_raise Ecto.NotFoundError, fn ->
  get(conn, ~p"/posts/#{post}")
end
```

However, you may prefer the implementation Phoenix generates by default as it ignores the specific details of the failure, and instead verifies what the browser would actually receive.

The tests for `new`, `edit`, and `show` actions are simpler variations of the tests we have seen so far. You can check the action implementation and their respective tests yourself. Now we are ready to move to JSON controller tests.

## JSON controller tests

So far we have been working with a generated HTML resource. However, let's take a look at how our tests look like when we generate a JSON resource.

First of all, run this command:

```console
$ mix phx.gen.json News Article articles title body
```

We chose a very similar concept to the Blog context <-> Post schema, except we are using a different name, so we can study these concepts in isolation.

After you run the command above, do not forget to follow the final steps output by the generator. Once all is done, we should run `mix test` and now have 35 passing tests:

```console
$ mix test
................

Finished in 0.6 seconds
35 tests, 0 failures

Randomized with seed 618478
```

You may have noticed that this time the scaffold controller has generated fewer tests. Previously it generated 16 (we went from 5 to 21) and now it generated 14 (we went from 21 to 35). That's because JSON APIs do not need to expose the `new` and `edit` actions. We can see this is the case in the resource we have added to the router at the end of the `mix phx.gen.json` command:

```elixir
resources "/articles", ArticleController, except: [:new, :edit]
```

`new` and `edit` are only necessary for HTML because they basically exist to assist users in creating and updating resources. Besides having less actions, we will notice the controller and view tests and implementations for JSON are drastically different from the HTML ones.

The only thing that is pretty much the same between HTML and JSON is the contexts and the schema, which, once you think about it, it makes total sense. After all, your business logic should remain the same, regardless if you are exposing it as HTML or JSON.

With the differences in hand, let's take a look at the controller tests.

### The index action

Open up `test/hello_web/controllers/article_controller_test.exs`. The initial structure is quite similar to `post_controller_test.exs`. So let's take a look at the tests for the `index` action. The `index` action itself is implemented in `lib/hello_web/controllers/article_controller.ex` like this:

```elixir
def index(conn, _params) do
  articles = News.list_articles()
  render(conn, :index, articles: articles)
end
```

The action gets all articles and renders the index template. Since we are talking about JSON, we don't have a `index.json.heex` template. Instead, the code that converts `articles` into JSON can be found directly in the ArticleJSON module, defined at `lib/hello_web/controllers/article_json.ex` like this:

```elixir
defmodule HelloWeb.ArticleJSON do
  alias Hello.News.Article

  def index(%{articles: articles}) do
    %{data: for(article <- articles, do: data(article))}
  end

  def show(%{article: article}) do
    %{data: data(article)}
  end

  defp data(%Article{} = article) do
    %{
      id: article.id,
      title: article.title,
      body: article.body
    }
  end
end
```

Since a controller render is a regular function call, we don't need any extra features to render JSON. We simply define functions for our `index` and `show` actions that return the map of JSON for articles.

Let's take a look at the test for the `index` action then:

```elixir
describe "index" do
  test "lists all articles", %{conn: conn} do
    conn = get(conn, ~p"/api/articles")
    assert json_response(conn, 200)["data"] == []
  end
end
```

It simply accesses the `index` path, asserts we got a JSON response with status 200 and that it contains a "data" key with an empty list, as we have no articles to return.

That was quite boring. Let's look at something more interesting.

### The `create` action

The `create` action is defined like this:

```elixir
def create(conn, %{"article" => article_params}) do
  with {:ok, %Article{} = article} <- News.create_article(article_params) do
    conn
    |> put_status(:created)
    |> put_resp_header("location", ~p"/api/articles/#{article}")
    |> render(:show, article: article)
  end
end
```

As we can see, it checks if an article could be created. If so, it sets the status code to `:created` (which translates to 201), it sets a "location" header with the location of the article, and then renders "show.json" with the article.

This is precisely what the first test for the `create` action verifies:

```elixir
describe "create article" do
  test "renders article when data is valid", %{conn: conn} do
    conn = post(conn, ~p"/articles", article: @create_attrs)
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get(conn, ~p"/api/articles/#{id}")

    assert %{
             "id" => ^id,
             "body" => "some body",
             "title" => "some title"
           } = json_response(conn, 200)["data"]
  end
```

The test uses `post/2` to create a new article and then we verify that the article returned a JSON response, with status 201, and that it had a "data" key in it. We pattern match the "data" on `%{"id" => id}`, which allows us to extract the ID of the new article. Then we perform a `get/2` request on the `show` route and verify that the article was successfully created.

Inside `describe "create article"`, we will find another test, which handles the failure scenario. Can you spot the failure scenario in the `create` action? Let's recap it:

```elixir
def create(conn, %{"article" => article_params}) do
  with {:ok, %Article{} = article} <- News.create_article(article_params) do
```

The `with` special form that ships as part of Elixir allows us to check explicitly for the happy paths. In this case, we are interested only in the scenarios where `News.create_article(article_params)` returns `{:ok, article}`, if it returns anything else, the other value will simply be returned directly and none of the contents inside the `do/end` block will be executed. In other words, if `News.create_article/1` returns `{:error, changeset}`, we will simply return `{:error, changeset}` from the action.

However, this introduces an issue. Our actions do not know how to handle the `{:error, changeset}` result by default. Luckily, we can teach Phoenix Controllers to handle it with the Action Fallback controller. At the top of `ArticleController`, you will find:

```elixir
  action_fallback HelloWeb.FallbackController
```

This line says: if any action does not return a `%Plug.Conn{}`, we want to invoke `FallbackController` with the result. You will find `HelloWeb.FallbackController` at `lib/hello_web/controllers/fallback_controller.ex` and it looks like this:

```elixir
defmodule HelloWeb.FallbackController do
  use HelloWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HelloWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
    |> render(:"404")
  end
end
```

You can see how the first clause of the `call/2` function handles the `{:error, changeset}` case, setting the status code to unprocessable entity (422), and then rendering "error.json" from the changeset view with the failed changeset.

With this in mind, let's look at our second test for `create`:

```elixir
test "renders errors when data is invalid", %{conn: conn} do
  conn = post(conn, ~p"/api/articles", article: @invalid_attrs)
  assert json_response(conn, 422)["errors"] != %{}
end
```

It simply posts to the `create` path with invalid parameters. This makes it return a JSON response, with status code 422, and a response with a non-empty "errors" key.

The `action_fallback` can be extremely useful to reduce boilerplate when designing APIs. You can learn more about the "Action Fallback" in the [Controllers guide](controllers.html).

### The `delete` action

Finally, the last action we will study is the `delete` action for JSON. Its implementation looks like this:

```elixir
def delete(conn, %{"id" => id}) do
  article = News.get_article!(id)

  with {:ok, %Article{}} <- News.delete_article(article) do
    send_resp(conn, :no_content, "")
  end
end
```

The new action simply attempts to delete the article and, if it succeeds, it returns an empty response with status code `:no_content` (204).

The test looks like this:

```elixir
describe "delete article" do
  setup [:create_article]

  test "deletes chosen article", %{conn: conn, article: article} do
    conn = delete(conn, ~p"/api/articles/#{article}")
    assert response(conn, 204)

    assert_error_sent 404, fn ->
      get(conn, ~p"/api/articles/#{article}")
    end
  end
end

defp create_article(_) do
  article = article_fixture()
  %{article: article}
end
```

It setups a new article, then in the test it invokes the `delete` path to delete it, asserting on a 204 response, which is neither JSON nor HTML. Then it verifies that we can no longer access said article.

That's all!

Now that we understand how the scaffolded code and their tests work for both HTML and JSON APIs, we are prepared to move forward in building and maintaining our web applications!
