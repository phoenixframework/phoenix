# Scopes

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Contexts guide](contexts.html).

The contexts guide briefly introduced the concept of scopes. Scopes are meant to be a way to identify the caller of a function that can be used to tie resources (or actions) to this caller. In a Phoenix application this is typically something like a user account. The generators use the scope to create a boundary between different callers, such that a resource created with `mix phx.gen.context` which is scoped to a user is - by default - only visible to and modifiable by that user. While this is a common use case, scopes are not limited to it. Another common use case for scopes it to provide information for logging or leaving an audit trail. By passing the scope to your context CRUD functions, you can rely on a well-defined data structure that can identify the entity performing the action.

In this guide, we will see how we can use scopes with the Phoenix generators. We will build a blog application where users can create and manage their own posts. Then, we will make changes such that everyone can see all posts, but only the author can edit them. We will also look at the technical details of how scopes are defined and used by the generators by implementing a custom scope from scratch.

## Creating a scoped blog application

In a new Phoenix application, let's scaffold the initial blog setup with `mix phx.gen.auth`:

```console
$ mix phx.gen.auth Accounts User users --live
* creating priv/repo/migrations/20250225102317_create_users_auth_tables.exs
* creating lib/my_blog/accounts/user_notifier.ex
* creating lib/my_blog/accounts/user.ex
* creating lib/my_blog/accounts/user_token.ex
...
* injecting lib/my_blog_web/components/layouts/root.html.heex

Please re-fetch your dependencies with the following command:

    $ mix deps.get

Remember to update your repository by running migrations:

    $ mix ecto.migrate

Once you are ready, visit "/users/register"
to create your account and then access "/dev/mailbox" to
see the account confirmation email.
```

Next, we'll scaffold the scoped blog posts with `mix phx.gen.live`:

```console
$ mix phx.gen.live Blog Post posts title:string body:text
* creating lib/my_blog_web/live/post_live/show.ex
* creating lib/my_blog_web/live/post_live/index.ex
* creating lib/my_blog_web/live/post_live/form.ex
* creating test/my_blog_web/live/post_live_test.exs
* creating lib/my_blog/blog/post.ex
* creating priv/repo/migrations/20250225102434_create_posts.exs
* creating lib/my_blog/blog.ex
* injecting lib/my_blog/blog.ex
* creating test/my_blog/blog_test.exs
* injecting test/my_blog/blog_test.exs
* creating test/support/fixtures/blog_fixtures.ex
* injecting test/support/fixtures/blog_fixtures.ex

Add the live routes to your browser scope in lib/my_blog_web/router.ex:

    live "/posts", PostLive.Index, :index
    live "/posts/new", PostLive.Form, :new
    live "/posts/:id", PostLive.Show, :show
    live "/posts/:id/edit", PostLive.Form, :edit


Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We'll need to add the routes to the correct section of the router:

```diff
...

   ## Authentication routes

   scope "/", MyBlogWeb do
     pipe_through [:browser, :require_authenticated_user]

     live_session :require_authenticated_user,
       on_mount: [{MyBlogWeb.UserAuth, :ensure_authenticated}] do
       live "/users/settings", UserLive.Settings, :edit
       live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
+
+      live "/admin/posts", PostLive.Index, :index
+      live "/admin/posts/new", PostLive.Form, :new
+      live "/admin/posts/:id", PostLive.Show, :show
+      live "/admin/posts/:id/edit", PostLive.Form, :edit
     end

     post "/users/update-password", UserSessionController, :update_password
   end

   scope "/", MyBlogWeb do
     pipe_through [:browser]

     live_session :current_user,
       on_mount: [{MyBlogWeb.UserAuth, :mount_current_scope}] do
       live "/users/register", UserLive.Registration, :new
       live "/users/log-in", UserLive.Login, :new
       live "/users/log-in/:token", UserLive.Confirmation, :new
+
+      live "/posts", PostLive.Index, :index
+      live "/posts/:id", PostLive.Show, :show
     end

     post "/users/log-in", UserSessionController, :create
     delete "/users/log-out", UserSessionController, :delete
   end

```

Because we want the posts themselves to be publicly accessible, we added public routes `/posts` and `/posts/:id`, as well as routes that require authentication prefixed with `/admin`. For listing and showing posts, we currently use the same LiveView for both public and admin routes. 

When you now start the server with `mix phx.server`, you will be able to register a new user and log in. Then, visit [http://localhost:4000/admin/posts](http://localhost:4000/admin/posts) to see the list of all your posts.

Now, let's add a new post by clicking on the "New Post" button and entering a title and body.

...

WIP NOT FINISHED, tbd if useful

## Technical details

The Phoenix generators use your application's config to store the configured scopes. A scope is defined by the following options:

```elixir
config :my_app, :scopes,
  user: [
    default: true,
    module: MyApp.Accounts.AuthScope,
    fixture: {MyApp.AccountsFixtures, :register_and_log_in_user},
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users
  ]
```

In this example, the scope is called `user` and it is the default scope that is automatically used when running `mix phx.gen.schema`, `mix phx.gen.context`, `mix phx.gen.live`, `mix phx.gen.html` and `mix phx.gen.json`. A scope needs a module that defines a struct, in this case `MyApp.Accounts.AuthScope`. Those structs are used as first argument to the generated context functions, like `list_posts/1`.

* `default` - a boolean that indicates if this scope is the default scope. There can only be one default scope defined.

* `module` - the module that defines the struct for this scope. The generators expect this module to have a `for_user/1` function that returns a struct where the identifying field is available under the `access_path` key:
  ```elixir
    defstruct user: nil

    def for_user(%{id: id} = user) do
      %MyApp.Accounts.AuthScope{
        user: user
      }
    end
  ```
  The scope name defines the name of the function. If the scope was called `admin`, the function would be `for_admin/1`.

* `fixture` - a tuple that is automatically imported into the generated test files. The first argument is the fixture module and the second argument is the name of a function that is registered as [`setup` callback](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#setup/1). The module is also expected to have a `NAME_scope_fixture/0` function that returns a unique scope struct for context tests, in this case `user_scope_fixture/0`.

* `assign_key` - the key where the scope struct is assigned to the [socket](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Socket.html#t:t/0) or [conn](https://hexdocs.pm/plug/Plug.Conn.html).

* `access_path` - a list of keys that define the path to the identifying field in the scope struct. The generators generate code like `where: schema_key == ^scope.user.id`.

* `schema_key` - the foreign key that ties the resource to the scope. New scoped schemas are created with a foreign key field named `schema_key` of type `schema_type` to the `schema_table` table.

* `schema_type` - the type of the foreign key field in the schema. Typically `:id` or `:binary_id`.

* `schema_migration_type` - the type of the foreign key column in the database. Used for the generated migration.

* `schema_table` - the name of the table where the foreign key points to.

## Implementing a custom scope

While the `mix phx.gen.auth` automatically generated scope for the applications, scopes can also be defined manually. This can be useful, for example, to retrofit an existing application with scopes.

For this example, we will implement a custom scope that gives each session their own scope. While this might not be useful in most real-world application as created resources would be inaccessible as soon as the session ends, it is a good example to understand how scopes work.

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

For tests, we'll also define a fixture module `test/support/fixtures/scope_fixtures.ex` with two functions:

```elixir
defmodule MyApp.ScopeFixtures do
  alias MyApp.Scope

  def session_scope_fixture(id \\ System.unique_integer()) do
    %Scope{id: id}
  end

  def assign_scope(%{conn: conn}) do
    id = System.unique_integer()
    scope = session_scope_fixture(id)

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
    fixture: {MyApp.ScopeFixtures, :assign_scope},
    assign_key: :current_scope,
    access_path: [:id],
    schema_key: :session_id,
    schema_type: :id,
    schema_migration_type: :bigint,
    schema_table: nil
  ]
```

Setting `schema_table` to `nil` means that the generated resources don't have a foreign key to the scope, but instead a normal `bigint` column that directly stores the scope's id.

We can now generate a new resource, for example with `phx.gen.html`:

```console
$ mix phx.gen.html Blog Post posts title:string
```

When you now visit [http://localhost:4000/posts](http://localhost:4000/posts), and create a new post, you will see that it is only visible to the current session. If you open a private browser window and visit the same URL, the previously created post is not visible. Similarly, if you create a new post in the private window, it is not visible in the other window. If you try to copy the URL of a post created in one session and access it in another, you will get an `Ecto.NoResultsError` error, which is automatically converted to 404 when the `debug_errors` setting is disabled.
