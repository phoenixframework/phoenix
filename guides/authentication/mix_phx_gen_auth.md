# mix phx.gen.auth

The `mix phx.gen.auth` command generates a flexible, pre-built authentication system into your Phoenix app. This generator allows you to quickly move past the task of adding authentication to your codebase and stay focused on the real-world problem your application is trying to solve.

## Getting started

> Before running this command, consider committing your work as it generates multiple files.

Let's start by running the following command from the root of our app (or `apps/my_app_web` in an umbrella app):

```console
$ mix phx.gen.auth Accounts User users

An authentication system can be created in two different ways:
- Using Phoenix.LiveView (default)
- Using Phoenix.Controller only

Do you want to create a LiveView based authentication system? [Y/n] Y
```

The authentication generators support Phoenix LiveView, for enhanced UX, so we'll answer `Y` here. You may also answer `n` for a controller based authentication system.

Either approach will create an `Accounts` context with an `Accounts.User` schema module. The final argument is the plural version of the schema module, which is used for generating database table names and route paths. The `mix phx.gen.auth` generator is similar to `mix phx.gen.html` except it does not accept a list of additional fields to add to the schema, and it generates many more context functions.

Since this generator installed additional dependencies in `mix.exs`, let's fetch those:

```console
$ mix deps.get
```

Now we need to verify the database connection details for the development and test environments in `config/` so the migrator and tests can run properly. Then run the following to create the database:

```console
$ mix ecto.setup
```

Let's run the tests to make sure our new authentication system works as expected.

```console
$ mix test
```

And finally, let's start our Phoenix server and try it out.

```console
$ mix phx.server
```

## Developer responsibilities

Since Phoenix generates this code into your application instead of building these modules into Phoenix itself, you now have complete freedom to modify the authentication system, so it works best with your use case. The one caveat with using a generated authentication system is it will not be updated after it's been generated. Therefore, as improvements are made to the output of `mix phx.gen.auth`, it becomes your responsibility to determine if these changes need to be ported into your application. Security-related and other important improvements will be explicitly and clearly marked in the `CHANGELOG.md` file and upgrade notes.

## Generated code

The following are notes about the generated authentication system.

### Password hashing

The password hashing mechanism defaults to `bcrypt` for Unix systems and `pbkdf2` for Windows systems. Both systems use the [Comeonin interface](https://hexdocs.pm/comeonin/).

The password hashing mechanism can be overridden with the `--hashing-lib` option. The following values are supported:

  * `bcrypt` - [bcrypt_elixir](https://hex.pm/packages/bcrypt_elixir)
  * `pbkdf2` - [pbkdf2_elixir](https://hex.pm/packages/pbkdf2_elixir)
  * `argon2` - [argon2_elixir](https://hex.pm/packages/argon2_elixir)

We recommend developers to consider using `argon2`, which is the most robust of all 3. The downside is that `argon2` is quite CPU and memory intensive, and you will need more powerful instances to run your applications on.

For more information about choosing these libraries, see the [Comeonin project](https://github.com/riverrun/comeonin).

### Forbidding access

The generated code ships with an authentication module with a handful of plugs that fetch the current user, require authentication and so on. For instance, in an app named Demo which had `mix phx.gen.auth Accounts User users` run on it, you will find a module named `DemoWeb.UserAuth` with plugs such as:

  * `fetch_current_user` - fetches the current user information if available
  * `require_authenticated_user` - must be invoked after `fetch_current_user` and requires that a current user exists and is authenticated
  * `redirect_if_user_is_authenticated` - used for the few pages that must not be available to authenticated users

### Confirmation

The generated functionality ships with an account confirmation mechanism, where users have to confirm their account, typically by email. However, the generated code does not forbid users from using the application if their accounts have not yet been confirmed. You can add this functionality by customizing the `require_authenticated_user` in the `Auth` module to check for the `confirmed_at` field (and any other property you desire).

### Notifiers

The generated code is not integrated with any system to send SMSes or emails for confirming accounts, resetting passwords, etc. Instead, it simply logs a message to the terminal. It is your responsibility to integrate with the proper system after generation.

Note that if you generated your Phoenix project with `mix phx.new`, your project is configured to use [Swoosh](https://hexdocs.pm/swoosh/Swoosh.html) mailer by default. To view notifier emails during development with Swoosh, navigate to `/dev/mailbox`.

### Tracking sessions

All sessions and tokens are tracked in a separate table. This allows you to track how many sessions are active for each account. You could even expose this information to users if desired.

Note that whenever the password changes (either via reset password or directly), all tokens are deleted, and the user has to log in again on all devices.

### User Enumeration attacks

A user enumeration attack allows someone to check if an email is registered in the application. The generated authentication code does not attempt to protect from such checks. For instance, when you register an account, if the email is already registered, the code will notify the user the email is already registered.

If your application is sensitive to enumeration attacks, you need to implement your own workflows, which tends to be very different from most applications, as you need to carefully balance security and user experience.

Furthermore, if you are concerned about enumeration attacks, beware of timing attacks too. For example, registering a new account typically involves additional work (such as writing to the database, sending emails, etc) compared to when an account already exists. Someone could measure the time taken to execute those additional tasks to enumerate emails. This applies to all endpoints (registration, confirmation, password recovery, etc.) that may send email, in-app notifications, etc.

### Case sensitiveness

The email lookup is made to be case-insensitive. Case-insensitive lookups are the default in MySQL and MSSQL. In SQLite3 we use [`COLLATE NOCASE`](https://www.sqlite.org/datatype3.html#collating_sequences) in the column definition to support it. In PostgreSQL, we use the [`citext` extension](https://www.postgresql.org/docs/current/citext.html).

Note `citext` is part of PostgreSQL itself and is bundled with it in most operating systems and package managers. `mix phx.gen.auth` takes care of creating the extension and no extra work is necessary in the majority of cases. If by any chance your package manager splits `citext` into a separate package, you will get an error while migrating, and you can most likely solve it by installing the `postgres-contrib` package.

### Concurrent tests

The generated tests run concurrently if you are using a database that supports concurrent tests, which is the case of PostgreSQL.

## More about `mix phx.gen.auth`

Check out `mix phx.gen.auth` for more details, such as using a different password hashing library, customizing the web module namespace, generating binary id type, configuring the default options, and using custom table names.

## Additional resources

The following links have more information regarding the motivation and design of the code this generates.

  * José Valim's blog post - [An upcoming authentication solution for Phoenix](https://dashbit.co/blog/a-new-authentication-solution-for-phoenix)
  * The [original `phx_gen_auth` repo][phx_gen_auth repo] (for Phoenix 1.5 applications) - This is a great resource to see discussions around decisions that have been made in earlier versions of the project.
  * [Original pull request on bare Phoenix app][auth PR]
  * [Original design spec](https://github.com/dashbitco/mix_phx_gen_auth_demo/blob/auth/README.md)

[phx_gen_auth repo]: https://github.com/aaronrenner/phx_gen_auth
[auth PR]: https://github.com/dashbitco/mix_phx_gen_auth_demo/pull/1
