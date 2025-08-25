# Scopes

A scope is a data structure used to keep information about the current request or session, such as the current user, the user's organization/company, permissions, and so on. Think of a scope as a container with information required by the majority of pages in your application. A scope can also hold request metadata, such as IP addresses.

Scopes play an important role in security. [OWASP](https://owasp.org/) lists "Broken access control" as a [top-10 security risk](https://owasp.org/Top10/). Most application data is private for a user, a team, or an organization. Your database CRUD operations must be properly scoped to the current user/team/organization. Phoenix generators such as `mix phx.gen.html`, `mix phx.gen.json`, and `mix phx.gen.live` automatically use your custom scopes.

Scopes are flexible. You can have more than one scope in your application and choose the specific scope when invoking a generator. When you run `mix phx.gen.auth`, it will automatically generate a scope for you, but you may also add your own.

This guide will:

* Show how `mix phx.gen.auth` generates a scope for you
* Discuss how generators, such as `mix phx.gen.context`, rely on scopes for security
* How to define your own scope from scratch and all valid options
* Augment the built-in scope with additional scopes

## phx.gen.auth

The task `mix phx.gen.auth` will generate a default scope. This scope ties the generated resources to the currently authenticated user. Let's see it in action:

```console
$ mix phx.gen.auth Accounts User users
```

The scope code is the same for the `--live` and `--no-live` variants of the generator.

Looking at the generated scope file `lib/my_app/accounts/scope.ex`, we can see that it defines a struct with a single `user` field, and a function `for_user/1` that, if given a `User` struct, returns a new `%Scope{}` for that user.

```elixir
defmodule MyApp.Accounts.Scope do
  alias MyApp.Accounts.User

  defstruct user: nil

  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
```

The scope is automatically fetched by the `fetch_current_scope_for_user` plug that is injected into the `:browser` pipeline:

```elixir
# router.ex
...
pipeline :browser do
  ...
  plug :fetch_current_scope_for_user
end
```

```elixir
# user_auth.ex
def fetch_current_scope_for_user(conn, _opts) do
  {user_token, conn} = ensure_user_token(conn)
  user = user_token && Accounts.get_user_by_session_token(user_token)
  assign(conn, :current_scope, Scope.for_user(user))
end
```

Similarly, for LiveViews, there is a pre-defined `mount_current_scope` hook that ensures
the scope is available:

```elixir
# user_auth.ex
def on_mount(:mount_current_scope, _params, session, socket) do
  {:cont, mount_current_scope(socket, session)}
end

defp mount_current_scope(socket, session) do
  Phoenix.Component.assign_new(socket, :current_scope, fn ->
    user =
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end

    Scope.for_user(user)
  end)
end
```

## Integration of scopes in the Phoenix generators

If a default scope is defined in your application's config, the generators will build scoped resources by default. The generated LiveViews / Controllers will automatically pass the scope to the context functions. `mix phx.gen.auth` automatically sets its scope as default, if there is not already a default scope defined:

```elixir
# config/config.exs
config :my_app, :scopes,
  user: [
    default: true,
    ...
  ]
```

We will look at the individual options in the next section.

Now let's look at the code generated once a default scope is set. We will use `mix phx.gen.live` as an example, but the ideas and the overall code will be similar to `mix phx.gen.html` and `mix phx.gen.json` too:

```console
$ mix phx.gen.live Blog Post posts title:string body:text
```

This creates a new `Blog` context, with a `Post` resource. To ensure the scope is available, for LiveViews the routes in your `router.ex` must be added to a `live_session` that ensures the user is authenticated. In this case, within the aptly named `required_authenticated_user` section:

```diff
   scope "/", MyAppWeb do
     pipe_through [:browser, :require_authenticated_user]

     live_session :require_authenticated_user,
       on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
       live "/users/settings", UserLive.Settings, :edit
       live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

+      live "/posts", PostLive.Index, :index
+      live "/posts/new", PostLive.Form, :new
+      live "/posts/:id", PostLive.Show, :show
+      live "/posts/:id/edit", PostLive.Form, :edit
     end

     post "/users/update-password", UserSessionController, :update_password
   end
```

> Although the router has a `scope` macro, the router `scope` and `current_scope` are ultimately distinct features which have similar purposes: to narrow down access to parts of our application, each acting at distinct layers (one at the router, the other at the data layer).

Now, let's look at the generated LiveView (`lib/my_app_web/live/post_live/index.ex`):

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Blog

  ...

  @impl true
  def mount(_params, _session, socket) do
    Blog.subscribe_posts(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Listing Posts")
     |> stream(:posts, Blog.list_posts(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Blog.get_post!(socket.assigns.current_scope, id)
    {:ok, _} = Blog.delete_post(socket.assigns.current_scope, post)

    {:noreply, stream_delete(socket, :posts, post)}
  end

  @impl true
  def handle_info({type, %MyApp.Blog.Post{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :posts, Blog.list_posts(socket.assigns.current_scope), reset: true)}
  end
end
```

Note that every function from the `Blog` context that we call gets the `current_scope` assign passed in as the first argument. The `list_posts/1` function then uses that information to properly filter posts:

```elixir
# lib/my_app/blog.ex
def list_posts(%Scope{} = scope) do
  Repo.all(from post in Post, where: post.user_id == ^scope.user.id)
end
```

The LiveView even subscribes to scoped PubSub messages and automatically updates the rendered list whenever a new post is created or an existing post is updated or deleted, while ensuring that only messages for the current scope are processed.

## Defining scopes

The Phoenix generators use your application's config to discover the available scopes. A scope is defined by the following options:

```elixir
config :my_app, :scopes,
  user: [
    default: true,
    module: MyApp.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: MyApp.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]
```

In this example, the scope is called `user` and it is the `default` scope that is automatically used when running `mix phx.gen.schema`, `mix phx.gen.context`, `mix phx.gen.live`, `mix phx.gen.html` and `mix phx.gen.json`. A scope needs a module that defines a struct, in this case `MyApp.Accounts.Scope`. Those structs are used as first argument to the generated context functions, like `list_posts/1`.

* `default` - a boolean that indicates if this scope is the default scope. There can only be one default scope defined.

* `module` - the module that defines the struct for this scope.

* `assign_key` - the key where the scope struct is assigned to the [socket](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Socket.html#t:t/0) or [conn](https://hexdocs.pm/plug/Plug.Conn.html).

* `access_path` - a list of keys that define the path to the identifying field in the scope struct. The generators generate code like `where: schema_key == ^scope.user.id`.

* `route_prefix` - (optional) a path template string for how resources should be nested. For example, `/organizations/:org` would generate routes like `/organizations/:org/posts`. The parameter segment (`:org`) will be replaced with the appropriate scope access value in templates and LiveViews.

* `route_access_path` - (optional) list of keys that define the path to the field used in route generation (if `route_prefix` is set). This is particularly useful for user-friendly URLs where you might want to use a slug instead of an ID. If not specified, it defaults to `Enum.drop(scope.access_path, -1)` or `access_path` if the former is empty. For example, if the `access_path` is `[:organization, :id]`, it defaults to `[:organization]`, assuming that the value at `scope.organization` implements the `Phoenix.Param` protocol.

* `schema_key` - the foreign key that ties the resource to the scope. New scoped schemas are created with a foreign key field named `schema_key` of type `schema_type` to the `schema_table` table.

* `schema_type` - the type of the foreign key field in the schema. Typically `:id` or `:binary_id`.

* `schema_migration_type` (optional) - the type of the foreign key column in the database. Used for the generated migration. It defaults to the default migration foreign keytype.

* `schema_table` - the name of the table where the foreign key points to.

* `test_data_fixture` - a module that is automatically imported into the context test file. It must have a `NAME_scope_fixture/0` function that returns a unique scope struct for context tests, in this case `user_scope_fixture/0`.

* `test_setup_helper` - the name of a function that is registered as [`setup` callback](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#setup/1) in LiveView / Controller tests. The function is expected to be imported in the test file. Usually, this is ensured by putting it into the `MyAppWeb.ConnCase` module.

While the `mix phx.gen.auth` automatically generates a scope, scopes can also be defined manually. This can be useful, for example, to retrofit an existing application with scopes or to define scopes that are not tied to a user.

For this example, we will implement a custom scope that gives each session its own scope. While this might not be useful in most real-world applications as created resources would be inaccessible as soon as the session ends, it is a good example to understand how scopes work. See the following section for an example on how to augment an existing scope with organizations (teams, companies, or similar).

First, let's define our scope module `lib/my_app/scope.ex`:

```elixir
defmodule MyApp.Scope do
  defstruct id: nil

  def for_id(id) do
    %MyApp.Scope{id: id}
  end
end
```

Next, we define a plug in our router that assigns a scope to each request:

```diff
   pipeline :browser do
     plug :accepts, ["html"]
     plug :fetch_session
     plug :fetch_live_flash
     plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
     plug :protect_from_forgery
     plug :put_secure_browser_headers
+    plug :assign_scope
   end
+
+  defp assign_scope(conn, _opts) do
+    if id = get_session(conn, :scope_id) do
+      assign(conn, :current_scope, MyApp.Scope.for_id(id))
+    else
+      id = System.unique_integer()
+
+      conn
+      |> put_session(:scope_id, id)
+      |> assign(:current_scope, MyApp.Scope.for_id(id))
+    end
+  end
```

For tests, we'll also define a fixture module `test/support/fixtures/scope_fixtures.ex`:

```elixir
defmodule MyApp.ScopeFixtures do
  alias MyApp.Scope

  def session_scope_fixture(id \\ System.unique_integer()) do
    %Scope{id: id}
  end
end
```

And then add a `setup` helper to our `test/support/conn_case.ex`:

```elixir
defmodule MyAppWeb.ConnCase do
  ...

  def put_scope_in_session(%{conn: conn}) do
    id = System.unique_integer()
    scope = MyApp.ScopeFixtures.session_scope_fixture(id)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:scope_id, id)

    %{conn: conn, scope: scope}
  end
end
```

Finally, we configure the scope in our application's `config/config.exs`:

```elixir
config :my_app, :scopes,
  session: [
    default: true,
    module: MyApp.Scope,
    assign_key: :current_scope,
    access_path: [:id],
    schema_key: :session_id,
    schema_type: :id,
    schema_migration_type: :bigint,
    schema_table: nil,
    test_data_fixture: MyApp.ScopeFixtures,
    test_setup_helper: :put_scope_in_session
  ]
```

Setting `schema_table` to `nil` means that the generated resources don't have a foreign key to the scope, but instead a normal `bigint` column that directly stores the scope's id.

We can now generate a new resource, for example with `phx.gen.html`:

```console
$ mix phx.gen.html Post posts title:string
```

When you now visit [http://localhost:4000/posts](http://localhost:4000/posts), and create a new post, you will see that it is only visible to the current session. If you open a private browser window and visit the same URL, the previously created post is not visible. Similarly, if you create a new post in the private window, it is not visible in the other window. If you try to copy the URL of a post created in one session and access it in another, you will get an `Ecto.NoResultsError` error, which is automatically converted to 404 when the `debug_errors` setting is disabled.

## Augmenting scopes

Let's assume that you used `mix phx.gen.auth` to generate a scope tied to users. But now you also create a new `organization` entity, where users can be members of:

```elixir
defmodule MyApp.Accounts.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}
  schema "organizations" do
    field :name, :string
    field :slug, :string
    ...

    many_to_many :users, MyApp.Accounts.User, join_through: "organizations_users"

    timestamps(type: :utc_datetime)
  end
end
```

First, we'd adjust our scope struct to also include the organization:

```diff
 defmodule MyApp.Accounts.Scope do
   alias MyApp.Accounts.User
   alias MyApp.Accounts.Organization

-  defstruct user: nil
+  defstruct user: nil, organization: nil

   def for_user(%User{} = user) do
     %__MODULE__{user: user}
   end

   def for_user(nil), do: nil
+
+  def put_organization(%__MODULE__{} = scope, %Organization{} = organization) do
+    %{scope | organization: organization}
+  end
 end
```

Let's also assume that the current organization is part of the URL path, like `http://localhost:4000/organizations/foo/posts`. Then, we'd adjust our router to fetch the organization from the path and assign it to the scope:

```diff
  # router.ex
  pipeline :browser do
    ...
    plug :fetch_current_scope_for_user
+   plug :assign_org_to_scope
  end
```

```elixir
# user_auth.ex
def assign_org_to_scope(conn, _opts) do
  current_scope = conn.assigns.current_scope
  if slug = conn.params["org"] do
    org = MyApp.Accounts.get_organization_by_slug!(current_scope, slug)
    assign(conn, :current_scope, MyApp.Accounts.Scope.put_organization(current_scope, org))
  else
    conn
  end
end
```

For LiveViews, we'll also need to add a new `:on_mount` hook and add it to `live_session`'s `on_mount` option in the router:

```diff
  # router.ex
  scope "/", MyAppWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {MyAppWeb.UserAuth, :mount_current_scope},
+       {MyAppWeb.UserAuth, :assign_org_to_scope}
      ] do
      ...
    end
  end
```

```elixir
# user_auth.ex
def on_mount(:assign_org_to_scope, %{"org" => slug}, _session, socket) do
  socket =
    case socket.assigns.current_scope do
      %{organization: nil} = scope ->
        org = MyApp.Accounts.get_organization_by_slug!(socket.assigns.current_scope, slug)
        Phoenix.Component.assign(socket, :current_scope, Scope.put_organization(scope, org))

      _ ->
        socket
    end

  {:cont, socket}
end

def on_mount(:assign_org_to_scope, _params, _session, socket), do: {:cont, socket}
```

This way, if a route is defined like `live /organizations/:org/posts`, the `assign_org_to_scope` plug would fetch the organization from the path and assign it to the scope. This code assumes that `get_organization_by_slug!/2` raises an `Ecto.NoResultsError` which would be automatically converted to `404`, but you could also handle the error explicitly and, for example, set an error flash and redirect to another page, like a dashboard. The `get_organization_by_slug!/2` function should also rely on the current scope to filter the organizations to those the user has access to.

Then, we are ready to define a new scope in our application's `config/config.exs` to generate resources scoped to the organization:

```elixir
config :my_app, :scopes,
  user: [
    ...
  ],
  organization: [
    module: MyApp.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:organization, :id],
    route_prefix: "/organizations/:org",
    route_access_path: [:organization, :slug],
    schema_key: :org_id,
    schema_type: :id,
    schema_table: :organizations,
    test_data_fixture: MyApp.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user_with_org
  ]
```

For the generated tests, we'll also need to define a fixture in `test/support/fixtures/accounts_fixtures.ex` and extend our `test/support/conn_case.ex`:

```elixir
defmodule MyApp.AccountsFixtures do
  ...

  def organization_scope_fixture(scope \\ user_scope_fixture()) do
    org = organization_fixture(scope)
    Scope.put_organization(scope, org)
  end
end
```

```elixir
defmodule MyAppWeb.ConnCase do
  ...

  def register_and_log_in_user_with_org(context) do
    %{conn: conn, user: _user, scope: scope} = register_and_log_in_user(context)
    %{conn: conn, scope: MyApp.AccountsFixtures.organization_scope_fixture(scope)}
  end
end
```

Now that our scope configuration includes the `route_prefix`, we can generate resources scoped to the organization, and all paths will be automatically generated with the correct organization slug:

```console
$ mix phx.gen.live Blog Post posts title:string body:text --scope organization
```

This shows that scopes are quite flexible, allowing you to keep a well-defined data structure, even when your application grows.

Most of the time, your application will have a single scope module, like in this example. But sometimes, you might want to create a new scope module, for example to completely separate a user-facing scope from an admin scope, where also the context functions are supposed to only be called by one of the two.

## Scope helpers

When working with more complex scopes, it is often useful to create some helper functions, which can conveniently be added to the scope module:

```elixir
defmodule MyApp.Accounts.Scope do
  alias MyApp.Accounts
  alias MyApp.Accounts.{User, Organization}

  defstruct user: nil, organization: nil

  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  def put_organization(%__MODULE__{} = scope, %Organization{} = organization) do
    %{scope | organization: organization}
  end

  def for(opts) when is_list(opts) do
    cond do
      opts[:user] && opts[:org] ->
        user = user(opts[:user])
        org = org(opts[:org])

        user
        |> for_user()
        |> put_organization(org)

      opts[:user] ->
        user = user(opts[:user])
        for_user(user)

      opts[:org] ->
        %__MODULE__{organization: org(opts[:org])}
    end
  end

  defp user(id) when is_integer(id) do
    Accounts.get_user!(id)
  end

  defp user(email) when is_binary(email) do
    Accounts.get_user_by_email(email)
  end

  defp org(id) when is_integer(id) do
    Accounts.get_organization!(id)
  end

  defp org(slug) when is_binary(slug) do
    Accounts.get_organization_by_slug!(slug)
  end
end
```

Then, you can alias the Scope module in your project's `.iex.exs`:

```elixir
alias MyApp.Accounts.Scope
```

And when working with scoped context functions, you can just do:

```elixir
iex> MyApp.Blog.list_posts(Scope.for(user: 1, org: "foo"))
...
iex> MyApp.Accounts.list_api_tokens(Scope.for(user: "john@doe.com"))
...
```
