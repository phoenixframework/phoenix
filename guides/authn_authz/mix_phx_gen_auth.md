# mix phx.gen.auth

The `mix phx.gen.auth` command generates a flexible, pre-built authentication system into your Phoenix app. This generator allows you to quickly move past the task of adding authentication to your codebase and stay focused on the real-world problem your application is trying to solve. It supports the following features:

- User registration with account confirmation by email
- Log in with magic links
- Opt-in password authentication
- "Sudo mode", also known as privileged authentication, where the user must confirm their identity before performing sensitive actions

## Getting started

> Before running this command, consider committing your work as it generates multiple files.

Let's start by running the following command from the root of our app:

```console
$ mix phx.gen.auth Accounts User users

An authentication system can be created in two different ways:
- Using Phoenix.LiveView (default)
- Using Phoenix.Controller only

Do you want to create a LiveView based authentication system? [Y/n] Y
```

The first argument is the context module followed by the schema module
and its plural name (used as the schema table name). The example above
will generate an `Accounts` context module with two schemas inside:
`User` and `UserToken`. The context module helps us group all of the
different schemas related to authentication. You may name the context
and schema according to your preferences.

The authentication generators support Phoenix LiveView, for enhanced UX,
so you should answer `Y` here. You may also answer `n` for a controller
based authentication system. Either approach will create the same context
and schemas, using the same table names and route paths.

Since this generator installed additional dependencies in `mix.exs`,
let's fetch those:

```console
$ mix deps.get
```

Now run the pending repository migrations:

```console
$ mix ecto.migrate
```

Let's run the tests to make sure our new authentication system works as expected.

```console
$ mix test
```

And finally, let's start our Phoenix server and try it out (note the new `Register` and `Log in` links at the top right of the default page).

```console
$ mix phx.server
```

## Developer responsibilities

Since Phoenix generates this code into your application instead of building these modules into Phoenix itself, you now have complete freedom to modify the authentication system, so it works best with your use case. The one caveat with using a generated authentication system is it will not be updated after it's been generated. Therefore, as improvements are made to the output of `mix phx.gen.auth`, it becomes your responsibility to determine if these changes need to be ported into your application. Security-related and other important improvements will be explicitly and clearly marked in the `CHANGELOG.md` file and upgrade notes.

## Generated code

The following are notes about the generated authentication system.

### Forbidding access

The generated code ships with an authentication module with a handful of plugs that fetch the current user, require authentication and so on. For instance, in an app named MyApp which had `mix phx.gen.auth Accounts User users` run on it, you will find a module named `MyAppWeb.UserAuth` with plugs such as:

  * `fetch_current_scope_for_user` - fetches the current user information if available and stores it as `:current_scope` assign
  * `require_authenticated_user` - must be invoked after `fetch_current_scope_for_user` and requires that a current user exists and is authenticated
  * `redirect_if_user_is_authenticated` - used for the few pages that must not be available to authenticated users (only generated for controller based authentication)
  * `require_sudo_mode` - used for pages that contain sensitive operations and enforces recent authentication

### Scopes

The generated code includes a scope module. For an app named MyApp which had `mix phx.gen.auth Accounts User users` run on it, you will find the following module at `lib/my_app/accounts/scope.ex`:

```elixir
defmodule MyApp.Accounts.Scope do
  # ...
  alias MyApp.Accounts.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
```

The scope data structure is stored in the assigns and available to your Controllers and LiveViews. As your application grows in complexity, this data structure can store important metadata such as the teams, companies, or organizations the user belongs to, permissions, telemetry information such as IP address and so forth.

Furthermore, future Phoenix generator invocations will automatically pass this data structure from your Controllers and LiveViews to most of [your context operations](contexts.md), making sure that future data is scoped to the current user/team/company/organization. Scopes are essential to enforce the user can only access data they own. You can learn more about them in the [Scopes](scopes.md) guide.

### Password hashing

The password hashing mechanism defaults to `bcrypt` for Unix systems and `pbkdf2` for Windows systems. Both systems use the [Comeonin interface](https://hexdocs.pm/comeonin/).

The password hashing mechanism can be overridden with the `--hashing-lib` option. The following values are supported:

  * `bcrypt` - [bcrypt_elixir](https://hex.pm/packages/bcrypt_elixir)
  * `pbkdf2` - [pbkdf2_elixir](https://hex.pm/packages/pbkdf2_elixir)
  * `argon2` - [argon2_elixir](https://hex.pm/packages/argon2_elixir)

We recommend developers to consider using `argon2`, which is the most robust of all 3. The downside is that `argon2` is quite CPU and memory intensive, and you will need more powerful instances to run your applications on.

For more information about choosing these libraries, see the [Comeonin project](https://github.com/riverrun/comeonin).

There are similar `:on_mount` hooks for LiveView based authentication.

### Notifiers

The generated code is not integrated with any system to send SMSes or emails for confirming accounts, resetting passwords, etc. Instead, it simply logs a message to the terminal. It is your responsibility to integrate with the proper system after generation.

Note that if you generated your Phoenix project with `mix phx.new`, your project is configured to use [Swoosh](https://hexdocs.pm/swoosh/Swoosh.html) mailer by default. To view notifier emails during development with Swoosh, navigate to `/dev/mailbox`.

### Concurrent tests

The generated tests run concurrently if you are using a database that supports concurrent tests, which is the case of PostgreSQL.

### More about `mix phx.gen.auth`

Check out `mix phx.gen.auth` for more details, such as using a different password hashing library, customizing the web module namespace, generating binary id type, configuring the default options, and using custom table names.

## Security considerations

### Tracking sessions

All sessions and tokens are tracked in a separate table. This allows you to track how many sessions are active for each account. You could even expose this information to users if desired.

Note that whenever the password changes (either via reset password or directly), all tokens are deleted, and the user has to log in again on all devices.

### User Enumeration attacks

A user enumeration attack allows someone to check if an email is registered in the application. The generated authentication code does not attempt to protect from such attacks. For instance, when you register an account, if the email is already registered, the code will notify the user the email is already registered.

If your application is sensitive to enumeration attacks, you need to implement your own workflows, which tends to be very different from most applications, as you need to carefully balance security and user experience.

Furthermore, if you are concerned about enumeration attacks, beware of timing attacks too. For example, registering a new account typically involves additional work (such as writing to the database, sending emails, etc) compared to when an account already exists. Someone could measure the time taken to execute those additional tasks to enumerate emails. This applies to all endpoints (registration, login, etc.) that may send email, in-app notifications, etc.

### Confirmation and credential pre-stuffing attacks

The generated functionality ships with an account confirmation mechanism, where users have to confirm their account, typically by email. Furthermore, to prevent security issues, the generated code does forbid users from using the application if their accounts have not yet been confirmed. If you want to change this behavior, please refer to the ["Mixing magic link and password registration" section](Mix.Tasks.Phx.Gen.Auth.html#module-mixing-magic-link-and-password-registration) of `mix phx.gen.auth`.

### Case sensitiveness

The email lookup is made to be case-insensitive. Case-insensitive lookups are the default in MySQL and MSSQL. In SQLite3 we use [`COLLATE NOCASE`](https://www.sqlite.org/datatype3.html#collating_sequences) in the column definition to support it. In PostgreSQL, we use the [`citext` extension](https://www.postgresql.org/docs/current/citext.html).

Note `citext` is part of PostgreSQL itself and is bundled with it in most operating systems and package managers. `mix phx.gen.auth` takes care of creating the extension and no extra work is necessary in the majority of cases. If by any chance your package manager splits `citext` into a separate package, you will get an error while migrating, and you can most likely solve it by installing the `postgres-contrib` package.

## Additional resources

### Migrating to Phoenix v1.8 magic links and sudo mode

Phoenix v1.8 added new features and simplified the authentication code. Developers are not required to migrate to the new generators, although we recommend setting up your own scope, as defined in the [Scopes](scopes.md) guide.

If you generated your authentication code with `mix phx.gen.auth` in Phoenix v1.7 or earlier and you want to migrate to the new generators, you can use the following pull requests as reference:

  * [Pull request for migrating LiveView based Phoenix 1.7 `phx.gen.auth` to magic links](https://github.com/SteffenDE/phoenix_gen_auth_magic_link/pull/1)
  * [Pull request for migrating controller based Phoenix 1.7 `phx.gen.auth` to magic links](https://github.com/SteffenDE/phoenix_gen_auth_magic_link/pull/2)

Keep in mind that the new authentication system fully removes registering an account with password, which simplifies both the user experience and the generated code. Therefore, when migrating, you should not change your existing migration files, instead, you must make the `hashed_password` column optional by setting `null: true`. Also, when migrating to the new system and removing features like "Forgot your password?", you must set the `hashed_password` of all accounts that have not been confirmed to `nil`, after making the column nullable, to avoid credential stuffing attacks. For this reason, we recommend deploying the migrated authentication system during low-traffic periods, where ideally no user who has just registered an account would have their password nullified. If those trade-offs are not acceptable, [you can add magic links on top of your existing authentication system without a complete migration, as discussed here](https://github.com/srcrip/phoenix-magic-links).

### Initial implementation

The following links describe the original implementation of the authentication system, the default up to Phoenix v1.7:

  * José Valim's blog post - [An upcoming authentication solution for Phoenix](https://dashbit.co/blog/a-new-authentication-solution-for-phoenix)
  * Berenice Medel's blog post on generating LiveViews for authentication (rather than conventional Controllers & Views) - [Bringing Phoenix Authentication to Life](https://fly.io/phoenix-files/phx-gen-auth/)
  * [Original design spec](https://github.com/dashbitco/mix_phx_gen_auth_demo/blob/auth/README.md)
  * [Pull request on bare Phoenix app](https://github.com/dashbitco/mix_phx_gen_auth_demo/pull/1)
