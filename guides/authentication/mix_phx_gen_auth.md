# mix phx.gen.auth

The `mix phx.gen.auth` command generates a flexible, pre-built authentication system into your phoenix app. This simple generator allows you to quickly move past the task of adding authentication to your codebase and stay focused on the real-world problem your application is trying to solve.

## Getting Started

Let's start by running the following command from the root of our app (or `apps/my_app_web` in an umbrella app):

    $ mix phx.gen.auth Accounts User users

This creates an `Accounts` context with an `Accounts.User` schema module. The final argument is the plural version of the schema module which is used for generating database table names and route helpers. The `mix phx.gen.auth` generator is similar to `mix phx.gen.html` except it does not accept a list of additional fields to add to the schema and it generates many more context functions.

Since this generator installed additional dependencies in `mix.exs`, let's fetch those dependencies:

    $ mix deps.get

Now we need to verify the database connection details for the development and test environments in `config/` so the migrator and tests can run properly. Then run the following to create the database:

    $ mix ecto.setup

Let's run the tests to make sure our new authentication system works as expected.

    $ mix test

And finally, let's start our phoenix server and try it out.

    $ mix phx.server

## Developer Responsibilities

Since phoenix generates this code into your application instead of building these modules into Phoenix itself, you now have complete freedom to modify the authentication system so it works best with your use case. The one caveat with using a generated authentication system is it will not be updated after it's been generated. Therefore as improvements are made to the output of `mix phx.gen.auth`, it becomes your responsibility to determine if these changes need to be ported into your application. Security-related and other important improvements will be explicitly and clearly marked in CHANGELOG and upgrade notes.

## Generated Code

The following are notes about the generated authentication system.

### Password hashing

The password hashing mechanism defaults to `bcrypt` for Unix systems and `pbkdf2` for Windows systems. Both systems use [the Comeonin interface](https://hexdocs.pm/comeonin/).

### Forbidding access

The generated code ships with an auth module with a handful of plugs that fetch the current user, require authentication and so on. For instance, in an app named Demo which had `mix phx.gen.auth Accounts User users` run on it, you will find a module named `DemoWeb.UserAuth` with plugs such as:

  * `fetch_current_user` - fetches the current user information if available
  * `require_authenticated_user` - must be invoked after `fetch_current_user` and requires that a current user exists and is authenticated
  * `redirect_if_user_is_authenticated` - used for the few pages that must not be available to authenticated users

### Confirmation

The generated functionality ships with an account confirmation mechanism, where users have to confirm their account, typically by email. However, the generated code does not forbid users from using the application if their accounts have not yet been confirmed. You can add this functionality by customizing the `require_authenticated_user` in the `Auth` module to check for the `confirmed_at` field (and any other property you desire).

### Notifiers

The generated code is not integrated with any system to send SMSs or emails for confirming accounts, resetting passwords, etc. Instead it simply logs a message to the terminal. It is your responsibility to integrate with the proper system after generation.

### Tracking sessions

All sessions and tokens are tracked in a separate table. This allows you to track how many sessions are active for each account. You could even expose this information to users if desired.

Note that whenever the password changes (either via reset password or directly), all tokens are deleted and the user has to log in again on all devices.

### Enumeration attacks

An enumeration attack allows an attacker to enumerate all emails registered in the application. The generated authentication code protects against enumeration attacks on all endpoints, except in the registration and update email forms. If your application is really sensitive to enumeration attacks, you need to implement your own registration workflow, which tends to be very different from the workflow for most applications.

### Case sensitiveness

The email lookup is made to be case insensitive. Case insensitive lookups are the default in MySQL and MSSQL but use the [`citext` extension in PostgreSQL](https://www.postgresql.org/docs/current/citext.html).

Note `citext` is part of Postgres itself and is bundled with it in most operating systems and package managers. `mix phx.gen.auth` takes care of creating the extension and no extra work is necessary in the majority of cases. If by any chance your package manager splits `citext` into a separate package, you will get an error while migrating and you can most likely solve it by installing the `postgres-contrib` package.

### Concurrent tests

The generated tests run concurrently if you are using a database that supports concurrent tests (Postgres).

## Additional resources

The following links have more information regarding the motivation and design of the code this generates.

  * José Valim's blog post - [An upcoming authentication solution for Phoenix](https://dashbit.co/blog/a-new-authentication-solution-for-phoenix)
  * The [original `phx_gen_auth` repo][phx_gen_auth repo] (for Phoenix 1.5 applications) - This is a great resource to see discussions around decisions that have been made in earlier versions of the project.
  * [Original pull request on bare phoenix app][auth pr]
  * [Original design spec](https://github.com/dashbitco/mix_phx_gen_auth_demo/blob/auth/README.md)

[phx_gen_auth repo]: https://github.com/aaronrenner/phx_gen_auth
[auth pr]: https://github.com/dashbitco/mix_phx_gen_auth_demo/pull/1
