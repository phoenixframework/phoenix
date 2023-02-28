# JSON and APIs

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Controllers guide](controllers.html).

You can also use the Phoenix Framework to build [Web APIs](https://en.wikipedia.org/wiki/Web_API). By default Phoenix supports JSON but you can bring any other rendering format you desire.

## The JSON API

For this guide let's create a simple JSON API to store our favourite links, that will support all the CRUD (Create, Read, Update, Delete) operations out of the box.

For this guide, we will use Phoenix generators to scaffold our API infrastructure:

```console
mix phx.gen.json Urls Url urls link:string title:string
* creating lib/hello_web/controllers/url_controller.ex
* creating lib/hello_web/controllers/url_json.ex
* creating lib/hello_web/controllers/changeset_json.ex
* creating test/hello_web/controllers/url_controller_test.exs
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/urls/url.ex
* creating priv/repo/migrations/20221129120234_create_urls.exs
* creating lib/hello/urls.ex
* injecting lib/hello/urls.ex
* creating test/hello/urls_test.exs
* injecting test/hello/urls_test.exs
* creating test/support/fixtures/urls_fixtures.ex
* injecting test/support/fixtures/urls_fixtures.ex
```

We will break those files into four categories:

  * Files in `lib/hello_web` responsible for effectively rendering JSON
  * Files in `lib/hello` responsible for defining our context and logic to persist links to the database
  * Files in `priv/repo/migrations` responsible for updating our database
  * Files in `test` to test our controllers and contexts

In this guide, we will explore only the first category of files. To learn more about how Phoenix stores and manage data, check out [the Ecto guide](ecto.md) and [the Contexts guide](contexts.md) for more information. We also have a whole section dedicating on testing.

At the end, the generator asks us to add the `/url` resource to our `:api` scope in `lib/hello_web/router.ex`:

```elixir
scope "/api", HelloWeb do
  pipe_through :api
  resources "/urls", UrlController, except: [:new, :edit]
end
```

The API scope uses the `:api` pipeline, which will run specific steps such as ensuring the client can handle JSON responses.

Then we need to update our repository by running migrations:

```console
mix ecto.migrate
```

### Trying out the JSON API

Before we go ahead and change those files, let's take a look at how our API behaves from the command line.

First, we need to start the server:

```console
mix phx.server
```

Next, let's make a smoke test to check our API is working with:

```console
curl -i http://localhost:4000/api/urls
```

If everything went as planned we should get a `200` response:

```console
HTTP/1.1 200 OK
cache-control: max-age=0, private, must-revalidate
content-length: 11
content-type: application/json; charset=utf-8
date: Fri, 06 May 2022 21:22:42 GMT
server: Cowboy
x-request-id: Fuyg-wMl4S-hAfsAAAUk

{"data":[]}
```

We didn't get any data because we haven't populated the database with any yet. So let's add some links:

```console
curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {"link":"https://phoenixframework.org", "title":"Phoenix Framework"}}'

curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {"link":"https://elixir-lang.org", "title":"Elixir"}}'
```

Now we can retrieve all links:

```console
curl -i http://localhost:4000/api/urls
```

Or we can just retrieve a link it's `id`:

```console
curl -i http://localhost:4000/api/urls/1
```

Next, we can update a link with:

```console
curl -iX PUT http://localhost:4000/api/urls/2 \
   -H 'Content-Type: application/json' \
   -d '{"url": {"title":"Elixir Programming Language"}}'
```

The response should be a `200` with the update link in the body.

Finally, we need to try out the removal of a link:

```console
curl -iX DELETE http://localhost:4000/api/urls/2 \
   -H 'Content-Type: application/json'
```

A `204` response should be returned to indicate the successful removal of the link.

## Rendering JSON

To understand how to render JSON, let's start with the `index` action from `UrlController` defined at `lib/hello_web/controllers/url_controller.ex`:

```elixir
  def index(conn, _params) do
    urls = Urls.list_urls()
    render(conn, :index, urls: urls)
  end
```

As we can see, this is not any different from how Phoenix renders HTML templates. We call `render/3`, passing the connection, the template we want our views to render (`:index`), and the data we want to make available to our views.

Phoenix typically uses one view per rendering format. When rendering HTML, we would use `HelloHTML`. Now that we are rendering JSON, we will find a `UrlJSON` view collocated with the template at `lib/hello_web/controllers/url_json.ex`. Let's open it up:

```elixir
defmodule HelloWeb.UrlJSON do
  alias Hello.Urls.Url

  @doc """
  Renders a list of urls.
  """
  def index(%{urls: urls}) do
    %{data: for(url <- urls, do: data(url))}
  end

  @doc """
  Renders a single url.
  """
  def show(%{url: url}) do
    %{data: data(url)}
  end

  defp data(%Url{} = url) do
    %{
      id: url.id,
      link: url.link,
      title: url.title
    }
  end
end
```

This view is very simple. The `index` function receives all URLs, and converts them into a list of maps. Those maps are placed inside the data key at the root, exactly as we saw when interfacing with our application from `cURL`. In other words, our JSON view converts our complex data into simple Elixir data-structures. Once our view layer returns, Phoenix uses the `Jason` library to encode JSON and send the response to the client.

If you explore the remaining the controller, you will learn the `show` action is similar to the `index` one. For `create`, `update`, and `delete` actions, Phoenix uses one other important feature, called "Action fallback".

## Action fallback

Action fallback allows us to centralize error handling code in plugs, which are called when a controller action fails to return a [`%Plug.Conn{}`](`t:Plug.Conn.t/0`) struct. These plugs receive both the `conn` which was originally passed to the controller action along with the return value of the action.

Let's say we have a `show` action which uses [`with`](`with/1`) to fetch a blog post and then authorize the current user to view that blog post. In this example we might expect `fetch_post/1` to return `{:error, :not_found}` if the post is not found and `authorize_user/3` might return `{:error, :unauthorized}` if the user is unauthorized. We could use our `ErrorHTML` and `ErrorJSON` views which are generated by Phoenix for every new application to handle these error paths accordingly:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, :show, post: post)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
        |> render(:"404")

      {:error, :unauthorized} ->
        conn
        |> put_status(403)
        |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
        |> render(:"403")
    end
  end
end
```

Now imagine you may need to implement similar logic for every controller and action handled by your API. This would result in a lot of repetition.

Instead we can define a module plug which knows how to handle these error cases specifically. Since controllers are module plugs, let's define our plug as a controller:

```elixir
defmodule HelloWeb.MyFallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: HelloWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(403)
    |> put_view(json: HelloWeb.ErrorJSON)
    |> render(:"403")
  end
end
```

Then we can reference our new controller as the `action_fallback` and simply remove the `else` block from our `with`:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  action_fallback HelloWeb.MyFallbackController

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, :show, post: post)
    end
  end
end
```

Whenever the `with` conditions do not match, `HelloWeb.MyFallbackController` will receive the original `conn` as well as the result of the action and respond accordingly.

## FallbackController and ChangesetJSON

With this knowledge in hand, we can explore the `FallbackController` (`lib/hello_web/controllers/fallback_controller.ex`) generated by `mix phx.gen.json`. In particular, it handles one clause (the other is generated as an example):

```elixir
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HelloWeb.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end
```

The goal of this clause is to handle the `{:error, changeset}` return types from the `HelloWeb.Urls` context and render them into rendered errors via the `ChangesetJSON` view. Let's open up `lib/hello_web/controllers/changeset_json.ex` to learn more:

```elixir
defmodule HelloWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &HelloWeb.CoreComponents.translate_error/1)}
  end
end
```

As we can see, it will convert the errors into a data structure, which will be rendered as JSON. The changeset is a data structure responsible for casting and validating data. For our example, it is defined in `Hello.Urls.Url.changeset/1`. Let's open up `lib/hello/urls/url.ex` and see its definition:

```elixir
  @doc false
  def changeset(url, attrs) do
    url
    |> cast(attrs, [:link, :title])
    |> validate_required([:link, :title])
  end
```

As you can see, the changeset requires both link and title to be given. This means we can try posting a url with no link and title and see how our API responds:

```console
curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {}}'

{"errors": {"link": ["can't be blank"], "title": ["can't be blank"]}}
```

Feel free to modify the `changeset` function and see how your API behaves.

## API-only applications

In case you want to generate a Phoenix application exclusively for APIs, you can pass
several options when invoking `mix phx.new`. Let's check which `--no-*` flags we need
to use to not generate the scaffolding that isn't necessary on our Phoenix application
for the REST API.

From your terminal run:

```console
mix help phx.new
```

The output should contain the following:

```text
  • --no-assets - do not generate the assets folder
  • --no-ecto - do not generate Ecto files
  • --no-html - do not generate HTML views
  • --no-gettext - do not generate gettext files
  • --no-dashboard - do not include Phoenix.LiveDashboard
  • --no-mailer - do not generate Swoosh mailer files
```

The `--no-html` is the obvious one we want to use when creating any Phoenix application for an API in order to leave out all the unnecessary HTML scaffolding. You may also pass `--no-assets`, if you don't want any of the asset management bit, `--no-gettext` if you don't support internationalization, and so on.

Also bear in mind that nothing stops you to have a backend that supports simultaneously the REST API and a Web App (HTML, assets, internationalization and sockets).
