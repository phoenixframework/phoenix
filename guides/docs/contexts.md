# Contexts

So far, we've built pages, wired up controller actions through our routers, and learned how Ecto allows data to be validated and persisted. Now it's time to tie it all together by writing web-facing features that interact with our greater Elixir application.

When building a Phoenix project, we are first and foremost building an Elixir application. Phoenix's job is to provide a web interface into our Elixir application. Naturally, we compose our applications with modules and functions, but simply defining a module with a few functions isn't enough when designing an application. It's vital to think about your application design when writing code. Let's find out how.

> How to read this guide:
Using the context generators is a great way for beginners and intermediate Elixir programmers alike to get up and running quickly while thoughtfully designing their applications. This guide focuses on those readers. On the other hand, experienced developers may get more mileage from nuanced discussions around application design. For those readers, we include a frequently asked questions (FAQ) section at the end of the guide which brings different perspectives to some design decisions made throughout the guide. Beginners can safely skip the FAQ sections and return later when they're ready to dig deeper.

## Thinking about design

Contexts are dedicated modules that expose and group related functionality. For example, anytime you call Elixir's standard library, be it `Logger.info/1` or `Stream.map/2`, you are accessing different contexts. Internally, Elixir's logger is made of multiple modules, such as `Logger.Config` and `Logger.Backends`, but we never interact with those modules directly. We call the `Logger` module the context, exactly because it exposes and groups all of the logging functionality.

Phoenix projects are structured like Elixir and any other Elixir project – we split our code into contexts. A context will group related functionality, such as posts and comments, often encapsulating patterns such as data access and data validation. By using contexts, we decouple and isolate our systems into manageable, independent parts.

Let's use these ideas to build out our web application. Our goal is to build a user system as well as a basic content management system for adding and editing page content. Let's get started!

### Adding an Accounts Context

User accounts are often wide-reaching across a platform so it's important to think upfront about writing a well-defined interface. With that in mind, our goal is to build an accounts API that handles creating, updating, and deleting user accounts, as well as authenticating user credentials. We'll start off with basic features, but as we add authentication later, we'll see how starting with a solid foundation allows us to grow our application naturally as we add functionality.

Phoenix includes the `phx.gen.html`, `phx.gen.json`, and `phx.gen.context` generators that apply the ideas of isolating functionality in our applications into contexts. These generators are a great way to hit the ground running while Phoenix nudges you in the right direction to grow your application. Let's put these tools to use for our new user accounts context.

In order to run the context generators, we need to come up with a module name that groups the related functionality that we're building. In the [Ecto guide](ecto.html), we saw how we can use Changesets and Repos to validate and persist user schemas, but we didn't integrate this with our application at large. In fact, we didn't think about where a "user" in our application should live at all. Let's take a step back and think about the different parts of our system. We know that we'll have users of our product. Along with users comes things like account login credentials and user registration. An `Accounts` context in our system is a natural place for our user functionality to live.

> Naming things is hard. If you're stuck when trying to come up with a context name when the grouped functionality in your system isn't yet clear, you can simply use the plural form of the resource you're creating. For example, a `Users` context for managing users. As you grow your application and the parts of your system become clear, you can simply rename the context to a more refined name at a later time.

Before we use the generators, we need to undo the changes we made in the Ecto guide, so we can give our user schema a proper home. Run these commands to undo our previous work:

```console
$ rm lib/hello/user.ex
$ rm priv/repo/migrations/*_create_user.exs
```

Next, let's reset our database so we also discard the table we have just removed:

```console
$ mix ecto.reset
Generated hello app
The database for Hello.Repo has been dropped
The database for Hello.Repo has been created

14:38:37.418 [info]  Already up
```

Now we're ready to create our accounts context. We'll use the `phx.gen.html` task which creates a context module that wraps up Ecto access for creating, updating, and deleting users, along with web files like controllers and templates for the web interface into our context. Run the following command at your project root:

```console
$ mix phx.gen.html Accounts User users name:string \
username:string:unique

* creating lib/hello_web/controllers/user_controller.ex
* creating lib/hello_web/templates/user/edit.html.eex
* creating lib/hello_web/templates/user/form.html.eex
* creating lib/hello_web/templates/user/index.html.eex
* creating lib/hello_web/templates/user/new.html.eex
* creating lib/hello_web/templates/user/show.html.eex
* creating lib/hello_web/views/user_view.ex
* creating test/hello_web/controllers/user_controller_test.exs
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170629175236_create_users.exs
* creating lib/hello/accounts/accounts.ex
* injecting lib/hello/accounts/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs

Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/users", UserController


Remember to update your repository by running migrations:

    $ mix ecto.migrate

```

Phoenix generated the web files as expected in `lib/hello_web/`. We can also see our context files were generated inside a `lib/hello/accounts/` directory. Note the difference between `lib/hello` and `lib/hello_web`. We have an `Accounts` module to serve as the public API for account functionality, as well as an `Accounts.User` struct, which is an Ecto schema for casting and validating user account data. Phoenix also provided web and context tests for us, which we'll look at later. For now, let's follow the instructions and add the route according to the console instructions, in `lib/hello_web/router.ex`:

```elixir
  scope "/", HelloWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
+   resources "/users", UserController
  end
```

With the new route in place, Phoenix reminds us to update our repo by running `mix ecto.migrate`. Let's do that now:

```console
$ mix ecto.migrate

[info]  == Running Hello.Repo.Migrations.CreateUsers.change/0 forward

[info]  create table users

[info]  create index users_username_index

[info]  == Migrated in 0.0s
```

Before we jump into the generated code, let's start the server with `mix phx.server` and visit [http://localhost:4000/users](http://localhost:4000/users). Let's follow the "New User" link and click the "Submit" button without providing any input. We should be greeted with the following output:

```
Oops, something went wrong! Please check the errors below.
```

When we submit the form, we can see all the validation errors inline with the inputs. Nice! Out of the box, the context generator included the schema fields in our form template and we can see our default validations for required inputs are in effect. Let's enter some example user data and resubmit the form:

```
User created successfully.

Show User
Name: Chris McCord
Username: chrismccord
```

If we follow the "Back" link, we get a list of all users, which should contain the one we just created. Likewise, we can update this record or delete it. Now that we've seen how it works in the browser, it's time to take a look at the generated code.

## Starting With Generators

That little `phx.gen.html` command packed a surprising punch. We got a lot of functionality out-of-the-box for creating, updating, and deleting users. This is far from a full-featured app, but remember, generators are first and foremost learning tools and a starting point for you to begin building real features. Code generation can't solve all your problems, but it will teach you the ins and outs of Phoenix and nudge you towards the proper mind-set when designing your application.

Let's first checkout the `UserController` that was generated in `lib/hello_web/controllers/user_controller.ex`:


```elixir
defmodule HelloWeb.UserController do
  use HelloWeb, :controller

  alias Hello.Accounts
  alias Hello.Accounts.User

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.html", users: users)
  end

  def new(conn, _params) do
    changeset = Accounts.change_user(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: user_path(conn, :show, user))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
  ...
end
```

We've seen how controllers work in our [controller guide](controllers.html), so the code probably isn't too surprising. What is worth noticing is how our controller calls into the `Accounts` context. We can see that the `index` action fetches a list of users with `Accounts.list_users/0`, and how users are persisted in the `create` action with `Accounts.create_user/1`. We haven't yet looked at the accounts context, so we don't yet know how user fetching and creation is happening under the hood – *but that's the point*. Our Phoenix controller is the web interface into our greater application. It shouldn't be concerned with the details of how users are fetched from the database or persisted into storage. We only care about telling our application to perform some work for us. This is great because our business logic and storage details are decoupled from the web layer of our application. If we move to a full-text storage engine later for fetching users instead of a SQL query, our controller doesn't need to be changed. Likewise, we can reuse our context code from any other interface in our application, be it a channel, mix task, or long-running process importing CSV data.

In the case of our `create` action, when we successfully create a user, we use `Phoenix.Controller.put_flash/2` to show a success message, and then we redirect to the `user_path`'s show page. Conversely, if `Accounts.create_user/1` fails, we render our `"new.html"` template and pass along the Ecto changeset for the template to lift error messages from.

Next, let's dig deeper and checkout our `Accounts` context in `lib/hello/accounts/accounts.ex`:

```elixir
defmodule Hello.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Hello.Repo

  alias Hello.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end
  ...
end
```

This module will be the public API for all account functionality in our system. For example, in addition to user account management, we may also handle user login credentials, account preferences, and password reset generation. If we look at the `list_users/0` function, we can see the private details of user fetching. And it's super simple. We have a call to `Repo.all(User)`. We saw how Ecto repo queries worked in [the Ecto guide](ecto.html), so this call should look familiar. Our `list_users` function is a generalized function specifying the *intent* of our code – namely to list users. The details of that intent where we use our Repo to fetch the users from our PostgreSQL database is hidden from our callers. This is a common theme we'll see re-iterated as we use the Phoenix generators. Phoenix will push us to think about where we have different responsibilities in our application, and then to wrap up those different areas behind well-named modules and functions that make the intent of our code clear, while encapsulating the details.

Now we know how data is fetched, but how are users persisted? Let's take a look at the `Accounts.create_user/1` function:

```elixir
  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
```

There's more documentation than code here, but a couple of things are important to highlight. First, we can see again that our Ecto Repo is used under the hood for database access. You probably also noticed the call to `User.changeset/2`. We talked about changesets before, and now we see them in action in our context.

If we open up the `User` schema in `lib/hello/accounts/user.ex`, it will look immediately familiar:

```elixir
defmodule Hello.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Hello.Accounts.User


  schema "users" do
    field :name, :string
    field :username, :string

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:name, :username])
    |> validate_required([:name, :username])
    |> unique_constraint(:username)
  end
end
```

This is just what we saw before when we ran the `mix phx.gen.schema` task, except here we see a `@doc false` above our `changeset/2` function. This tells us that while this function is publicly callable, it's not part of the public context API. Callers that build changesets do so via the context API. For example, `Accounts.create_user/1` calls into our `User.changeset/2` to build the changeset from user input. Callers, such as our controller actions, do not access `User.changeset/2` directly. All interaction with our user changesets is done through the public `Accounts` context.

## In-context Relationships

Our basic user account features are nice, but let's take it up a notch by supporting user login credentials. We won't implement a complete authentication system, but we'll give ourselves a good start to grow such a system from. Many authentication solutions couple the user credentials to an account in a one-to-one fashion, but this often causes issues. For example, supporting different login methods, such as social login or recovery email addresses, will cause major code changes. Let's set up a credentials association that will allow us to start off tracking a single credential per account, but easily support more features later.

For now, user credentials will contain only email information. Our first order of business is to decide where credentials live in the application. We have our `Accounts` context, which manages user accounts. User credentials is a natural fit here. Phoenix is also smart enough to generate code inside an existing context, which makes adding new resources to a context a breeze. Run the following command at your project root:

> Sometimes it may be tricky to determine if two resources belong to the same context or not. In those cases, prefer distinct contexts per resource and refactor later if necessary. Otherwise you can easily end-up with large contexts of loosely related entities. In other words: if you are unsure, you should prefer explicit modules (contexts) between resources.

```console
$ mix phx.gen.context Accounts Credential credentials \
email:string:unique user_id:references:users

* creating lib/hello/accounts/credential.ex
* creating priv/repo/migrations/20170629180555_create_credentials.exs
* injecting lib/hello/accounts/accounts.ex
* injecting test/hello/accounts/accounts_test.exs

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

This time around, we used the `phx.gen.context` task, which is just like `phx.gen.html`, except it doesn't generate the web files for us. Since we already have controllers and templates for managing users, we can integrate the new credential features into our existing web form.

We can see from the output that Phoenix generated an `accounts/credential.ex` file for our `Accounts.Credential` schema, as well as a migration. Notably, phoenix said it was `* injecting` code into the existing `accounts/accounts.ex` context file and test file. Since our `Accounts` module already exists, Phoenix knows to inject our code here.

Before we run our migrations, we need to make one change to the generated migration to enforce data integrity of user account credentials. In our case, we want a user's credentials to be deleted when the parent user is removed. Make the following change to your `*_create_credentials.exs` migration file in `priv/repo/migrations/`:

```diff
  def change do
    create table(:credentials) do
      add :email, :string
-     add :user_id, references(:users, on_delete: :nothing)
+     add :user_id, references(:users, on_delete: :delete_all),
+                   null: false

      timestamps()
    end

    create unique_index(:credentials, [:email])
    create index(:credentials, [:user_id])
  end
```

We changed the `:on_delete` option from `:nothing` to `:delete_all`, which will generate a foreign key constraint that will delete all credentials for a given user when the user is removed from the database. Likewise, we also passed `null: false` to disallow creating credentials without an existing user. By using a database constraint, we enforce data integrity at the database level, rather than relying on ad-hoc and error-prone application logic.

Next, let's migrate up our database as Phoenix instructed:

```console
$ mix ecto.migrate
mix ecto.migrate
Compiling 2 files (.ex)
Generated hello app

[info]  == Running Hello.Repo.Migrations.CreateCredentials.change/0 forward

[info]  create table credentials

[info]  create index credentials_email_index

[info]  create index credentials_user_id_index

[info]  == Migrated in 0.0s
```

Before we integrate credentials in the web layer, we need to let our context know how to associate users and credentials. First, open up `lib/accounts/user.ex` and add the following association:


```elixir
- alias Hello.Accounts.User
+ alias Hello.Accounts.{User, Credential}


  schema "users" do
    field :name, :string
    field :username, :string
+   has_one :credential, Credential

    timestamps()
  end


```

We used `Ecto.Schema`'s `has_one` macro to let Ecto know how to associate our parent User to a child Credential. Next, let's add the relationships in the opposite direction in `accounts/credential.ex`:

```elixir
- alias Hello.Accounts.Credential
+ alias Hello.Accounts.{Credential, User}


  schema "credentials" do
    field :email, :string
-   field :user_id, :id
+   belongs_to :user, User

    timestamps()
  end

```

We used the `belongs_to` macro to map our child relationship to the parent `User`. With our schema associations set up, let's open up `accounts/accounts.ex` and make the following changes to the generated `list_users` and `get_user!`  functions:

```elixir
  def list_users do
    User
    |> Repo.all()
    |> Repo.preload(:credential)
  end

  def get_user!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(:credential)
  end
```

We rewrote the `list_users/0` and `get_user!/1` to preload the credential association whenever we fetch users. The Repo preload functionality fetches a schema's association data from the database, then places it inside the schema. When operating on a collection, such as our query in `list_users`, Ecto can efficiently preload the associations in a single query. This allows us to represent our `%Accounts.User{}` structs as always containing credentials without the caller having to worry about fetching the extra data.

Next, let's expose our new feature to the web by adding the credentials input to our user form. Open up `lib/hello_web/templates/user/form.html.eex` and key in the new credential form group above the submit button:


```eex
  ...
+ <div class="form-group">
+   <%= inputs_for f, :credential, fn cf -> %>
+     <%= label cf, :email, class: "control-label" %>
+     <%= text_input cf, :email, class: "form-control" %>
+     <%= error_tag cf, :email %>
+   <% end %>
+ </div>

  <div class="form-group">
    <%= submit "Submit", class: "btn btn-primary" %>
  </div>
```

We used `Phoenix.HTML`'s `inputs_for` function to add an associations nested fields within the parent form. Within the nested inputs, we rendered our credential's email field and included the `label` and `error_tag` helpers just like our other inputs.

Next, let's show the user's email address in the user show template. Add the following code to `lib/hello_web/templates/user/show.html.eex`:

```eex
  ...
+ <li>
+   <strong>Email:</strong>
+   <%= @user.credential.email %>
+ </li>
</ul>

```

Now if we visit `http://localhost:4000/users/new`, we'll see the new email input, but if you try to save a user, you'll find that the email field is ignored. No validations are run telling you it was blank and the data was not saved, and at the end you'll get an exception `(UndefinedFunctionError) function nil.email/0 is undefined or private`. What gives?

We used Ecto's `belongs_to` and `has_one` associations to wire-up how our data is related at the context level, but remember this is decoupled from our web-facing user input. To associate user input to our schema associations, we need to handle it the way we've handled other user input so far – in changesets. Remove the alias for Credential added by the generator and modify your `alias Hello.Accounts.User`, `create_user/1` and `update_user/2` functions in your `Accounts` context to build a changeset which knows how to cast user input with nested credential information:

```elixir
- alias Hello.Accounts.User
+ alias Hello.Accounts.{User, Credential}
  ...

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
+   |> Ecto.Changeset.cast_assoc(:credential, with: &Credential.changeset/2)
    |> Repo.update()
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
+   |> Ecto.Changeset.cast_assoc(:credential, with: &Credential.changeset/2)
    |> Repo.insert()
  end
  ...

- alias Hello.Accounts.Credential
```
We updated the functions to pipe our user changeset into `Ecto.Changeset.cast_assoc/2`. Ecto's `cast_assoc/2` allows us to tell the changeset how to cast user input to a schema relation. We also used the `:with` option to tell Ecto to use our `Credential.changeset/2` function to cast the data. This way, any validations we perform in `Credential.changeset/2` will be applied when saving the `User` changeset.

Finally, if you visit `http://localhost:4000/users/new` and attempt to save an empty email address, you'll see the proper validation error message. If you enter valid information, the data will be casted and persisted properly.

```
Show User
Name: Chris McCord
Username: chrismccord
Email: chris@example.com
```

It's not much to look at yet, but it works! We added relationships within our context complete with data integrity enforced by the database. Not bad. Let's keep building!

## Adding Account functions

As we've seen, your context modules are dedicated modules that expose and group related functionality. Phoenix generates generic functions, such as `list_users` and `update_user`, but they only serve as a basis for you to grow your business logic and application from. To begin extending our `Accounts` context with real features, let's address an obvious issue of our application – we can create users with credentials in our system, but they have no way of signing in with those credentials. Building a complete user authentication system is beyond the scope of this guide, but let's get started with a basic email-only sign-in page that allows us to track a current user's session. This will let us focus on extending our `Accounts` context while giving you a good start to grow a complete authentication solution from.

To start, let's think of a function name that describes what we want to accomplish. To authenticate a user by email address, we'll need a way to lookup that user and verify their entered credentials are valid. We can do this by exposing a single function on our `Accounts` context.

    > user = Accounts.authenticate_by_email_password(email, password)

That looks nice. A descriptive name that exposes the intent of our code is best. This function makes it crystal clear what purpose it serves, while allowing our caller to remain blissfully unaware of the internal details. Make the following additions to your `lib/hello/accounts/accounts.ex` file:

```elixir
def authenticate_by_email_password(email, _password) do
  query =
    from u in User,
      inner_join: c in assoc(u, :credential),
      where: c.email == ^email

  case Repo.one(query) do
    %User{} = user -> {:ok, user}
    nil -> {:error, :unauthorized}
  end
end
```

We defined an `authenticate_by_email_password/2` function, which discards the password field for now, but you could integrate tools like [guardian](https://github.com/ueberauth/guardian) or [comeonin](https://github.com/riverrun/comeonin) as you continue building your application. All we need to do in our function is find the user with matching credentials and return the `%Accounts.User{}` struct in a `:ok` tuple, or an `{:error, :unauthorized}` value to let the caller know their authentication attempt has failed.

Now that we can authenticate a user from our context, let's add a login page to our web layer. First create a new controller in `lib/hello_web/controllers/session_controller.ex`:

```elixir
defmodule HelloWeb.SessionController do
  use HelloWeb, :controller

  alias Hello.Accounts

  def new(conn, _) do
    render(conn, "new.html")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_by_email_password(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: "/")
      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Bad email/password combination")
        |> redirect(to: session_path(conn, :new))
    end
  end

  def delete(conn, _) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
```

We defined a `SessionController` to handle users signing in and out of the application. Our `new` action is responsible for simply rendering a "new session" form, which posts out to the create action of our controller. In `create`, we pattern match the form fields and call into our `Accounts.authenticate_by_email_password/2` that we just defined. If successful, we use `Plug.Conn.put_session/3` to place the authenticated user's ID in the session, and redirect to the home page with a successful welcome message. We also called `configure_session(conn, renew: true)` before redirecting to avoid session fixation attacks. If authentication fails, we add a flash error message, and redirect to the sign-in page for the user to try again. To finish the controller, we support a `delete` action which simply calls `Plug.Conn.configure_session/2` to drop the session and redirect to the home page.

Next, let's wire up our session routes in `lib/hello_web/router.ex`:


```elixir
  scope "/", HelloWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/users", UserController
+   resources "/sessions", SessionController, only: [:new, :create, :delete],
                                              singleton: true
  end
```

We used `resources` to generate a set of routes under the `"/session"` path. This is what we've done for other routes, except this time we also passed the `:only` option to limit which routes are generated, since we only need to support `:new`, `:create`, and `:delete` actions. We also used the `singleton: true` option, which defines all the RESTful routes, but does not require a resource ID to be passed along in the URL. We don't need an ID in the URL because our actions are always scoped to the "current" user in the system. The ID is always in the session. Before we finish our router, let's add an authentication plug to the router that will allow us to lock down certain routes after a user has used our new session controller to sign-in. Add the following function to `lib/hello_web/router.ex`:


```elixir
  defp authenticate_user(conn, _) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> Phoenix.Controller.put_flash(:error, "Login required")
        |> Phoenix.Controller.redirect(to: "/")
        |> halt()
      user_id ->
        assign(conn, :current_user, Hello.Accounts.get_user!(user_id))
    end
  end
```

We defined an `authenticate_user/2` plug in the router which simply uses `Plug.Conn.get_session/2` to check for a `:user_id` in the session. If we find one, it means a user has previously authenticated, and we call into `Hello.Accounts.get_user!/1` to place our `:current_user` into the connection assigns. If we don't have a session, we add a flash error message, redirect to the homepage, and we use `Plug.Conn.halt/1` to halt further plugs downstream from being invoked. We won't use this new plug quite yet, but it will be ready and waiting as we add authenticated routes in just a moment.

Lastly, we need `SessionView` to render a template for our login form. Create a new file in `lib/hello_web/views/session_view.ex:`

```elixir
defmodule HelloWeb.SessionView do
  use HelloWeb, :view
end
```

Next, add a new template in `lib/hello_web/templates/session/new.html.eex:`

```eex
<h1>Sign in</h1>

<%= form_for @conn, session_path(@conn, :create), [method: :post, as: :user], fn f -> %>
  <div class="form-group">
    <%= text_input f, :email, placeholder: "Email" %>
  </div>

  <div class="form-group">
    <%= password_input f, :password, placeholder: "Password" %>
  </div>

  <div class="form-group">
    <%= submit "Login" %>
  </div>
<% end %>

<%= form_for @conn, session_path(@conn, :delete), [method: :delete, as: :user], fn _ -> %>
  <div class="form-group">
    <%= submit "logout" %>
  </div>
<% end %>
```

To keep things simple, we added both our sign-in and sign-out forms in this template. For our sign-in form, we pass the `@conn` directly to `form_for`, pointing our form action at `session_path(@conn, :create)`. We also pass the `as: :user` option which tells Phoenix to wrap the form parameters inside a `"user"` key. Next, we used the `text_input` and `password_input` functions to send up an `"email"` and `"password"` parameter.

For logging out, we simply defined a form that sends the `DELETE` HTTP method to server's session delete path. Now if you visit the sign-in page at http://localhost:4000/sessions/new and enter a bad email address, you should be greeted with your flash message. Entering a valid email address will redirect to the home page with a success flash notice.

With authentication in place, we're in good shape to begin building out our next features.


## Cross-context dependencies

Now that we have the beginnings of user account and credential features, let's begin to work on the other main features of our application – managing page content. We want to support a content management system (CMS) where authors can create and edit pages of the site. While we could extend our `Accounts` context with CMS features, if we step back and think about the isolation of our application, we can see it doesn't fit. An accounts system shouldn't care at all about a CMS system. The responsibilities of our `Accounts` context is to manage users and their credentials, not handle page content changes. There's a clear need here for a separate context to  handle these responsibilities. Let's call it `CMS`.

Let's create a `CMS` context to handle basic CMS duties. Before we write code, let's imagine we have the following CMS feature requirements:

1. Page creation and updates
2. Pages belong to Authors who are responsible for publishing changes
3. Author information should appear with the page, and include information such as author bio and role within the CMS, such as `"editor"`, `"writer"`, or `"intern"`.

From the description, it's clear we need a `Page` resource for storing page information. What about our author information? While we could extend our existing `Accounts.User` schema to include information such as bio and role, that would violate the responsibilities we've set up for our contexts. Why should our Account system now be aware of author information? Worse, with a field like "role", the CMS role in the system will likely conflict or be confused with other account roles for our application. There's a better way.

Applications with "users" are naturally heavily user driven. After all, our software is typically designed to be used by human end-users one way or another. Instead of extending our `Accounts.User` struct to track every field and responsibility of our entire platform, it's better to keep those responsibilities with the modules who own that functionality. In our case, we can create a `CMS.Author` struct that holds author specific fields as it relates to a CMS. Now we can place fields like "role" and "bio" here, where they naturally live. Likewise, we also gain specialized datastructures in our application that are suited to the domain that we are operating in, rather than a single `%User{}` in the system that has to be everything to everyone.

With our plan set, let's get to work. Run the following command to generate our new context:

```
$ mix phx.gen.html CMS Page pages title:string body:text \
views:integer --web CMS

* creating lib/hello_web/controllers/cms/page_controller.ex
* creating lib/hello_web/templates/cms/page/edit.html.eex
* creating lib/hello_web/templates/cms/page/form.html.eex
* creating lib/hello_web/templates/cms/page/index.html.eex
* creating lib/hello_web/templates/cms/page/new.html.eex
* creating lib/hello_web/templates/cms/page/show.html.eex
* creating lib/hello_web/views/cms/page_view.ex
* creating test/hello_web/controllers/cms/page_controller_test.exs
* creating lib/hello/cms/page.ex
* creating priv/repo/migrations/20170629195946_create_pages.exs
* creating lib/hello/cms/cms.ex
* injecting lib/hello/cms/cms.ex
* creating test/hello/cms/cms_test.exs
* injecting test/hello/cms/cms_test.exs

Add the resource to your CMS :browser scope in lib/hello_web/router.ex:

    scope "/cms", HelloWeb.CMS, as: :cms do
      pipe_through :browser
      ...
      resources "/pages", PageController
    end


Remember to update your repository by running migrations:

    $ mix ecto.migrate

```

The `views` attribute on the pages will not be updated directly by the user, so let's remove it from the generated form. Open `lib/hello_web/templates/cms/page/form.html.eex` and remove this part:

```eex
-  <div class="form-group">
-    <%= label f, :views, class: "control-label" %>
-    <%= number_input f, :views, class: "form-control" %>
-    <%= error_tag f, :views %>
-  </div>
```

Also, change `lib/hello/cms/page.ex` to remove `:views` from the permitted params:

```elixir
  def changeset(%Page{} = page, attrs) do
    page
-    |> cast(attrs, [:title, :body, :views])
-    |> validate_required([:title, :body, :views])
+    |> cast(attrs, [:title, :body])
+    |> validate_required([:title, :body])
  end
```

Finally, open up the new file in `priv/repo/migrations` to ensure the `views` attribute will have a default value:

```elixir
    create table(:pages) do
      add :title, :string
      add :body, :text
-     add :views, :integer
+     add :views, :integer, default: 0

      timestamps()
    end
```

This time we passed the `--web` option to the generator. This tells Phoenix what namespace to use for the web modules, such as controllers and views. This is useful when you have conflicting resources in the system, such as our existing `PageController`, as well as a way to naturally namespace paths and functionality of different features, like a CMS system. Phoenix instructed us to add a new `scope` to the router for a `"/cms"` path prefix. Let's copy paste the following into our `lib/hello_web/router.ex`, but we'll make one modification to the `pipe_through` macro:


```
  scope "/cms", HelloWeb.CMS, as: :cms do
    pipe_through [:browser, :authenticate_user]

    resources "/pages", PageController
  end

```

We added the `:authenticate_user` plug to require a signed-in user for all routes within this CMS scope. With our routes in place, we can migrate up the database:

```
$ mix ecto.migrate

Compiling 12 files (.ex)
Generated hello app

[info]  == Running Hello.Repo.Migrations.CreatePages.change/0 forward

[info]  create table pages

[info]  == Migrated in 0.0s
```

Now, let's fire up the server with `mix phx.server` and visit `http://localhost:4000/cms/pages`. If we haven't logged in yet, we'll be redirected to the home page with a flash error message telling us to sign in. Let's sign in at `http://localhost:4000/sessions/new`, then re-visit `http://localhost:4000/cms/pages`. Now that we're authenticated, we should see a familiar resource listing for pages, with a `New Page` link.

Before we create any pages, we need page authors. Let's run the `phx.gen.context` generator to generate an `Author` schema along with injected context functions:

```
$ mix phx.gen.context CMS Author authors bio:text role:string \
genre:string user_id:references:users:unique

* creating lib/hello/cms/author.ex
* creating priv/repo/migrations/20170629200937_create_authors.exs
* injecting lib/hello/cms/cms.ex
* injecting test/hello/cms/cms_test.exs

Remember to update your repository by running migrations:

    $ mix ecto.migrate

```

We used the context generator to inject code, just like when we generated our credentials code. We added fields for the author bio, their role in the content management system, the genre the author writes in, and lastly a foreign key to a user in our accounts system. Since our accounts context is still the authority on end-users in our application, we will depend on it for our CMS authors. That said, any information specific to authors will stay in the authors schema. We could also decorate our `Author` with user account information by using virtual fields and never expose the `User` structure. This would ensure consumers of the CMS API are protected from changes in the `User` context.

Before we migrate our database, we need to handle data integrity once again in the newly generated `*_create_authors.exs` migration. Open up the new file in `priv/repo/migrations` and make the following change to the foreign key constraint:

```elixir
  def change do
    create table(:authors) do
      add :bio, :text
      add :role, :string
      add :genre, :string
-     add :user_id, references(:users, on_delete: :nothing)
+     add :user_id, references(:users, on_delete: :delete_all),
+                   null: false

      timestamps()
    end

    create unique_index(:authors, [:user_id])
  end
```

We used the `:delete_all` strategy again to enforce data integrity. This way, when a user is deleted from the application through `Accounts.delete_user/1)`, we don't have to rely on application code in our `Accounts` context to worry about cleaning up the `CMS` author records. This keeps our application code decoupled and the data integrity enforcement where it belongs – in the database.


Before we continue, we have a final migration to generate. Now that we have an authors table, we can associate pages and authors. Let's add an `author_id` field to the pages table. Run the following command to generate a new migration:

```
$ mix ecto.gen.migration add_author_id_to_pages

* creating priv/repo/migrations
* creating priv/repo/migrations/20170629202117_add_author_id_to_pages.exs
```

Now open up the new `*_add_author_id_to_pages.exs` file in `priv/repo/migrations` and key this in:

```elixir
  def change do
    alter table(:pages) do
      add :author_id, references(:authors, on_delete: :delete_all),
                      null: false
    end

    create index(:pages, [:author_id])
  end
```

We used the `alter` macro to add a new `author_id` field to the pages table, with a foreign key to our authors table. We also used the `on_delete: :delete_all` option again to prune any pages when a parent author is deleted from the application.

Now let's migrate up:

```
$ mix ecto.migrate

[info]  == Running Hello.Repo.Migrations.CreateAuthors.change/0 forward

[info]  create table authors

[info]  create index authors_user_id_index

[info]  == Migrated in 0.0s

[info]  == Running Hello.Repo.Migrations.AddAuthorIdToPages.change/0 forward

[info]  == Migrated in 0.0s
```

With our database ready, let's integrate authors and posts in the CMS system.

## Cross-context data

Dependencies in your software are often unavoidable, but we can do our best to limit them where possible and lessen the maintenance burden when a dependency is necessary. So far, we've done a great job isolating the two main contexts of our application from each other, but now we have a necessary dependency to handle.

Our `Author` resource serves to keep the responsibilities of representing an author inside the CMS, but ultimately for an author to exist at all, an end-user represented by an `Accounts.User` must be present. Given this, our `CMS` context will have a data dependency on the `Accounts` context. With that in mind, we have two options. One is to expose APIs on the `Accounts` contexts that allows us to efficiently fetch user data for use in the CMS system, or we can use database joins to fetch the dependent data. Both are valid options given your tradeoffs and application size, but joining data from the database when you have a hard data dependency is just fine for a large class of applications. If you decide to break out coupled contexts into entirely separate applications and databases at a later time, you still gain the benefits of isolation. This is because your public context APIs will likely remain unchanged.

Now that we know where our data dependencies exist, let's add our schema associations so we can tie pages to authors and authors to users. Make the following changes to `lib/hello/cms/page.ex`:


```elixir
- alias Hello.CMS.Page
+ alias Hello.CMS.{Page, Author}


  schema "pages" do
    field :body, :string
    field :title, :string
    field :views, :integer
+   belongs_to :author, Author

    timestamps()
  end
```

We added a `belongs_to` relationships between pages and their authors.
Next, let's add the association in the other direction in `lib/hello/cms/author.ex`:


```elixir

- alias Hello.CMS.Author
+ alias Hello.CMS.{Author, Page}


  schema "authors" do
    field :bio, :string
    field :genre, :string
    field :role, :string

-   field :user_id, :id
+   has_many :pages, Page
+   belongs_to :user, Hello.Accounts.User

    timestamps()
  end
```

We added the `has_many` association for author pages, and then introduced our data dependency on the `Accounts` context by wiring up the `belongs_to` association to our `Accounts.User` schema.

With our associations in place, let's update our `CMS` context to require an author when creating or updating a page. We'll start off with data fetching changes. Open up your `CMS` context in `lib/hello/cms/cms.ex` and replace the `list_pages/0`, and `get_page!/1` functions with the following definitions:

```elixir
  alias Hello.CMS.{Page, Author}
  alias Hello.Accounts

  def list_pages do
    Page
    |> Repo.all()
    |> Repo.preload(author: [user: :credential])
  end

  def get_page!(id) do
    Page
    |> Repo.get!(id)
    |> Repo.preload(author: [user: :credential])
  end

  def get_author!(id) do
    Author
    |> Repo.get!(id)
    |> Repo.preload(user: :credential)
  end
```

We started by rewriting the `list_pages/0` function to preload the associated author, user, and credential data from the database. Next, we rewrote `get_page!/1` and `get_author!/1` to also preload the necessary data.

With our data access functions in place, let's turn our focus towards persistence. We can fetch authors alongside pages, but we haven't yet allowed authors to be persisted when we create or edit pages. Let's fix that. Open up `lib/hello/cms/cms.ex` and make the following changes:


```elixir
def create_page(%Author{} = author, attrs \\ %{}) do
  %Page{}
  |> Page.changeset(attrs)
  |> Ecto.Changeset.put_change(:author_id, author.id)
  |> Repo.insert()
end

def ensure_author_exists(%Accounts.User{} = user) do
  %Author{user_id: user.id}
  |> Ecto.Changeset.change()
  |> Ecto.Changeset.unique_constraint(:user_id)
  |> Repo.insert()
  |> handle_existing_author()
end
defp handle_existing_author({:ok, author}), do: author
defp handle_existing_author({:error, changeset}) do
  Repo.get_by!(Author, user_id: changeset.data.user_id)
end
```

There's a bit of a code here, so let's break it down. First, we rewrote the `create_page` function to require a `CMS.Author` struct, which represents the author publishing the post. We then take our changeset and pass it to `Ecto.Changeset.put_change/2` to place the `author_id` association in the changeset. Next, we use `Repo.insert` to insert the new page into the database, containing our associated `author_id`.

Our CMS system requires an author to exist for any end-user before they publish posts, so we added an `ensure_author_exists` function to programmatically allow authors to be created. Our new function accepts an `Accounts.User` struct and either finds the existing author in the application with that `user.id`, or creates a new author for the user. Our authors table has a unique constraint on the `user_id` foreign key, so we are protected from a race condition allowing duplicate authors. That said, we still need to protect ourselves from racing the insert of another user. To accomplish this, we use a purpose-built changeset with `Ecto.Changeset.change/1` which accepts a new `Author` struct with our `user_id`. The changeset's only purpose is to convert a unique constraint violation into an error we can handle. After attempting to insert the new author with `Repo.insert/1`, we pipe to `handle_existing_author/1` which matches on the success and error cases. For the success case, we are done and simply return the created author, otherwise we use `Repo.get_by!` to fetch the author for the `user_id` that already exists.

That wraps up our `CMS` changes. Now, let's update our web layer to support our additions. Before we update our individual CMS controller actions, we need to make a couple of additions to the `CMS.PageController` plug pipeline. First, we must ensure an author exists for end-users accessing the CMS, and we need to authorize access to page owners.

Open up your generated `lib/hello_web/controllers/cms/page_controller.ex` and make the following additions:

```elixir

  plug :require_existing_author
  plug :authorize_page when action in [:edit, :update, :delete]

  ...

  defp require_existing_author(conn, _) do
    author = CMS.ensure_author_exists(conn.assigns.current_user)
    assign(conn, :current_author, author)
  end

  defp authorize_page(conn, _) do
    page = CMS.get_page!(conn.params["id"])

    if conn.assigns.current_author.id == page.author_id do
      assign(conn, :page, page)
    else
      conn
      |> put_flash(:error, "You can't modify that page")
      |> redirect(to: cms_page_path(conn, :index))
      |> halt()
    end
  end
```

We added two new plugs to our `CMS.PageController`. The first plug, `:require_existing_author`, runs for every action in this controller. The `require_existing_author/2` plug calls into our `CMS.ensure_author_exists/1` and passes in the `current_user` from the connection assigns. After finding or creating the author, we use `Plug.Conn.assign/3` to place a `:current_author` key into the assigns for use downstream.

Next, we added an `:authorized_page` plug that makes use of plug's guard clause feature where we can limit the plug to only certain actions. The definition for our `authorize_page/2` plug first fetches the page from the connection params, then does an authorization check against the `current_author`. If our current author's ID matches the fetched page ID, we have verified the page's owner is accessing the page and we simply assign the `page` into the connection assigns to be used in the controller action. If our authorization fails, we add a flash error message, redirect to the page index screen, and then call `Plug.Conn.halt/1` to prevent the plug pipeline from continuing and invoking the controller action.

With our new plugs in place, we can now modify our `create`, `edit`, `update`, and `delete` actions to make use of the new values in the connection assigns:

```elixir
  def edit(conn, _) do
-   page = CMS.get_page!(id)
-   changeset = CMS.change_page(page)
+   changeset = CMS.change_page(conn.assigns.page)
-   render(conn, "edit.html", page: page, changeset: changeset)
+   render(conn, "edit.html", changeset: changeset)
  end

- def create(conn, %{"id" => id, "page" => page_params}) do
+ def create(conn, %{"page" => page_params}) do
-   case CMS.create_page(page_params) do
+   case CMS.create_page(conn.assigns.current_author, page_params) do
      {:ok, page} ->
        conn
        |> put_flash(:info, "Page created successfully.")
        |> redirect(to: cms_page_path(conn, :show, page))
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

- def update(conn, %{"id" => id, "page" => page_params}) do
+ def update(conn, %{"page" => page_params}) do
-   page = CMS.get_page!(id)
-   case CMS.update_page(page, page_params) do
+   case CMS.update_page(conn.assigns.page, page_params) do
      {:ok, page} ->
        conn
        |> put_flash(:info, "Page updated successfully.")
        |> redirect(to: cms_page_path(conn, :show, page))
      {:error, %Ecto.Changeset{} = changeset} ->
-       render(conn, "edit.html", page: page, changeset: changeset)
+       render(conn, "edit.html", changeset: changeset)
    end
  end

- def delete(conn, %{"id" => id}) do
+ def delete(conn, _) do
-   page = CMS.get_page!(id)
-   {:ok, _page} = CMS.delete_page(page)
+   {:ok, _page} = CMS.delete_page(conn.assigns.page)

    conn
    |> put_flash(:info, "Page deleted successfully.")
    |> redirect(to: cms_page_path(conn, :index))
  end
```

We modified the `create` action to grab our `current_author` from the connection assigns, which was placed there by our `require_existing_author` plug. We then passed our current author into `CMS.create_page` where it will be used to associate the author to the new page. Next, we changed the `update` action to pass the `conn.assigns.page` into `CMS.update_page/2`, rather than fetching it directly in the action. Since our `authorize_page` plug already fetched the page and placed it into the assigns, we can simply reference it here in the action. Similarly, we updated the `delete` action to pass the `conn.assigns.page` into the `CMS` rather than fetching the page in the action.

To complete the web changes, let's display the author when showing a page. First, open up `lib/hello_web/views/cms/page_view.ex` and add a helper function to handle formatting the author's name:

```elixir
defmodule HelloWeb.CMS.PageView do
  use HelloWeb, :view

  alias Hello.CMS

  def author_name(%CMS.Page{author: author}) do
    author.user.name
  end
end
```

Next, let's open up `lib/hello_web/templates/cms/page/show.html.eex` and make use of our new function:

```diff
+ <li>
+   <strong>Author:</strong>
+   <%= author_name(@page) %>
+ </li>
</ul>
```

Now, fire up your server with `mix phx.server` and try it out. Visit `http://localhost:4000/cms/pages/new` and save a new page.

```
Page created successfully.

Show Page Title: Home
Body: Welcome to Phoenix!
Views: 0
Author: Chris
```

And it works! We now have two isolated contexts responsible for user accounts and content management. We coupled the content management system to accounts where necessary, while keeping each system isolated wherever possible. This gives us a great base to grow our application from.

## Adding CMS functions

Just like we extended our `Accounts` context with new application-specific functions like `Accounts.authenticate_by_email_password/2`, let's extend our generated `CMS` context with new functionality. For any CMS system, the ability to track how many times a page has been viewed is essential for popularity ranks. While we could try to use the existing `CMS.update_page` function, along the lines of `CMS.update_page(user, page, %{views: page.views + 1})`, this would not only be prone to race conditions, but it would also require the caller to know too much about our CMS system. To see why the race condition exists, let's walk through the possible execution of events:

Intuitively, you would assume the following events:

  1. User 1 loads the page with count of 13
  2. User 1 saves the page with count of 14
  3. User 2 loads the page with count of 14
  4. User 2 loads the page with count of 15

While in practice this would happen:

  1. User 1 loads the page with count of 13
  2. User 2 loads the page with count of 13
  3. User 1 saves the page with count of 14
  4. User 2 saves the page with count of 14

The race conditions would make this an unreliable way to update the existing table since multiple callers may be updating out of date view values. There's a better way.

Again, let's think of a function name that describes what we want to accomplish.

    > page = CMS.inc_page_views(page)

That looks great. Our callers will have no confusion over what this function does and we can wrap up the increment in an atomic operation to prevent race conditions.

Open up your CMS context (`lib/hello/cms/cms.ex`), and add this new function:


```elixir
def inc_page_views(%Page{} = page) do
  {1, [%Page{views: views}]} =
    Repo.update_all(
      from(p in Page, where: p.id == ^page.id),
      [inc: [views: 1]], returning: [:views])

  put_in(page.views, views)
end
```

We built a query for fetching the current page given its ID which we pass to `Repo.update_all`. Ecto's `Repo.update_all` allows us to perform batch updates against the database, and is perfect for atomically updating values, such as incrementing our views count. The result of the repo operation returns the number of updated records, along with the selected schema values specified by the `returning` option. When we receive the new page views, we use `put_in(page.views, views)` to place the new view count within the page.

With our context function in place, let's make use of it in our CMS page controller. Update your `show` action in `lib/hello_web/controllers/cms/page_controller.ex` to call our new function:


```elixir
def show(conn, %{"id" => id}) do
  page =
    id
    |> CMS.get_page!()
    |> CMS.inc_page_views()

  render(conn, "show.html", page: page)
end
```

We modified our `show` action to pipe our fetched page into `CMS.inc_page_views/1`, which will return the updated page. Then we rendered our template just as before. Let's try it out. Refresh one of your pages a few times and watch the view count increase.

We can also see our atomic update in action in the ecto debug logs:

```
[debug] QUERY OK source="pages" db=3.1ms
UPDATE "pages" AS p0 SET "views" = p0."views" + $1 WHERE (p0."id" = $2)
RETURNING p0."views" [1, 3]
```

Good work!

As we've seen, designing with contexts gives you a solid foundation to grow your application from. Using discrete, well-defined APIs that expose the intent of your system allows you to write more maintainable applications with reusable code.

## FAQ

### Returning Ecto structures from context APIs

As we explored the context API, you might have wondered:

> If one of the goals of our context is to encapsulate Ecto Repo access, why does `create_user/1` return an `Ecto.Changeset` struct when we fail to create a user?

The answer is we've decided to expose `%Ecto.Changeset{}` as a public *data-structure* in our application. We saw before how changesets allow us to track field changes, perform validations, and generate error messages. Its use here is decoupled from the private Repo access and Ecto changeset API internals. We're exposing a data structure that the caller understands which contains the rich information like field errors. Conveniently for us, the `phoenix_ecto` project implements the necessary `Phoenix.Param` and [`Phoenix.HTML.FormData`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.FormData.html) protocols which know how to handle `%Ecto.Changeset{}`'s for things like form generation and error messages. You can also think about it as being as if you had defined your own `%Accounts.Changes{}` struct for the same purpose and implemented the Phoenix protocols for the web-layer integration.


### Strategies for cross-context workflows

Our CMS context supports lazily creating authors in the system when a user decides to publish page content. This makes sense for our use case because not all users of our system will be CMS authors. But what if our use case were for when all users of our app are indeed authors?

If we require a `CMS.Author` to exist every time an `Accounts.User` is created, we have to think carefully where to place this dependency. We know our `CMS` context depends on the `Accounts` context, but it's important to avoid cyclic dependencies across our contexts. For example, imagine we changed our `Accounts.create_user` function to:

```elixir
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Ecto.Changeset.cast_assoc(:credential, with: &Credential.changeset/2)
  |> Ecto.Changeset.put_assoc(:author, %Author{...})
  |> Repo.insert()
end
```

This may accomplish what we want, but now we need to wire up the schema relationships in the `Accounts` context to the `CMS` author. Worse, we have now taken our isolated `Accounts` context and required it to know about a content management system. This isn't what we want for isolated responsibilities in our application. There's a better way to handle these requirements.

If you find yourself in similar situations where you feel your use case is requiring you to create circular dependencies across contexts, it's a sign you need a new context in the system to handle these application requirements. In our case, what we really want is an interface that handles all requirements when a user is created or registers in our application. To handle this, we could create a `UserRegistration` context, which calls into both the `Accounts` and `CMS` APIs to create a user, then associate a CMS author. Not only would this allow our Accounts to remain as isolated as possible, it gives us a clear, obvious API to handle `UserRegistration` needs in the system. If you take this approach, you can also use tools like `Ecto.Multi` to handle transactions across different context operations without deeply coupling the internal database calls. Part of our `UserRegistration` API could look something like this:

```elixir
defmodule Hello.UserRegistration do
  alias Ecto.Multi
  alias Hello.{Accounts, CMS}

  def register_user(params) do
    Multi.new()
    |> Multi.run(:user, fn _ -> Accounts.create_user(params) end)
    |> Multi.run(:author, fn %{user: user} ->
      {:ok, CMS.ensure_author_exists(user)}
    end)
    |> Repo.transaction()
  end
end
```
We can take advantage of `Ecto.Multi` to create a pipeline of operations that can be run inside a transaction of our `Repo`. If any given operation fails, the transaction will be rolled back and an error will be returned containing which operation failed, as well as the changes up to that point. In our `register_user/1` example, we specified two operations, one that calls into `Accounts.create_user/1` and another that passes the newly created user to `CMS.ensure_author_exits/1`. The final step of our function is to invoke the operations with `Repo.transaction/1`.

The `UserRegistration` setup is likely simpler to implement than the dynamic author system we built – we decided to take the harder path exactly because those are decisions developers take on their applications every day.
