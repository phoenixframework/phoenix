Sending email from a Phoenix application is really easy. Before we begin, we'll need an account with Mailgun - we won't actually be able to send mail without it. Once we have an account, though, the rest will be straightforward.

First, [sign up at Mailgun](https://mailgun.com/signup). They have a generous number of free emails per month, so we can get going with a free account.

Once we have an account, we'll get a sandbox through which we can send mail. The url of that sandbox will be our domain unless we choose to create a custom one through Mailgun.

Now that we have an account, we'll need to add `mailgun` as a dependency to our project. We'll do that in the `deps/0` function in `mix.exs`.

```elixir
defp deps do
  [{:phoenix, "~> 1.1.0"},
   {:phoenix_ecto, "~> 2.0"},
   {:postgrex, ">= 0.0.0"},
   {:phoenix_html, "~> 2.3"},
   {:phoenix_live_reload, "~> 1.0", only: :dev},
   {:cowboy, "~> 1.0"},
   {:mailgun, "~> 0.1.2"}]
end
```

Next, we'll need to run `mix deps.get` to bring the `mailgun` package into our application.

### Configuration

We'll also need to configure our `:mailgun_domain` and `:mailgun_key` in `config/config.ex`.

The `:mailgun_domain` will be a full url, something like this `https://api.mailgun.net/v3/sandbox-our-domain.mailgun.org`. The `:mailgun_key` will be a long string - "key-another-long-string".

For security reasons, it's important to not commit these values to a public source code repository. There are a couple of ways we can accomplish this.

One way is quick, but it requires us to set environment variables for our `:mailgun_domain` and `:mailgun_key` in all of our environments - development, production, and whichever other environments we might define. With the environment variables set, we can reference them in our `config/config.exs` file.

```elixir
config :hello_phoenix,
       mailgun_domain: System.get_env("MAILGUN_DOMAIN"),
       mailgun_key: System.get_env("MAILGUN_API_KEY")
```

There's another way which doesn't require environment variables for all environments, but is a little more complex to set up. This method mimics the way that `config/prod.secret.exs` works by creating a `config/config.secret.exs` file which will apply to all environments. We won't be using `prod.secret.exs` itself, because we will need these configuration values in development as well as production. Here goes.

The first thing we will do is add a line to the `.gitignore` file for a new `config/config.secret.exs` file. This will keep `config.secret.exs` out of our git repository.

```elixir
. . .
# The config/prod.secret.exs file by default contains sensitive
# data and you should not commit it into version control.
#
# Alternatively, you may comment the line below and commit the
# secrets file as long as you replace its contents by environment
# variables.
/config/prod.secret.exs
/config/config.secret.exs
```

The next step is to create the `config/config.secret.exs` file with our `mailgun` configuration in it.

```elixir
use Mix.Config

config :hello_phoenix,
       mailgun_domain: "https://api.mailgun.net/v3/sandbox-our-domain.mailgun.org",
       mailgun_key: "key-another-long-string"
```

Finally, we'll need to import `config.secret.exs` into our regular `config/config.exs` file.

```elixir
. . .
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
import_config "config.secret.exs"
```

Since our `config/config.secret.exs` file won't be in our repository, we'll need to take some extra steps when we deploy our application. Please see the [Deployment Introduction Guide](http://www.phoenixframework.org/docs/deployment) for more information.

### The Client Module

In order for our application to interact with Mailgun, we'll need a client module. Let's define one here `lib/hello_phoenix/mailer.ex`. When we `use` the `Mailgun.Client` module in the second line, we pass our configuration to the `mailgun` package, and we import `mailgun`'s `send_email/1` function into our mailer.

```elixir
defmodule HelloPhoenix.Mailer do
  use Mailgun.Client,
      domain: Application.get_env(:hello_phoenix, :mailgun_domain),
      key: Application.get_env(:hello_phoenix, :mailgun_key)
end
```

> Note The filesystem watcher does not monitor files in the `lib` directory for changes in order to recompile them. This means that if we update the mailer client, we'll need to restart the server in order for those changes to take effect.

With this in place, we can start creating our custom email functions. Web applications may send any number of different types of emails - welcome emails after signup, password confirmations, activity notifications - the list goes on. For each type of email, we'll define a new function which will call `send_email/1`, passing in a keyword list of arguments.

Let's say we want to send a welcome email to new users formatted as plain text. We'll need to know who to send the email to, as well as the "from" address, subject, and body of the email. This will be sent as a plain text email because we've specified the `:text` option.

```elixir
def send_welcome_text_email(email_address) do
  send_email to: email_address,
             from: "us@example.com",
             subject: "Welcome!",
             text: "Welcome to HelloPhoenix!"
end
```

Sending this email is as easy as invoking the function with an email address, from wherever we want to in our application.

```elixir
HelloPhoenix.Mailer.send_welcome_text_email("us@example.com")
```

Since we're just getting started, it would be great to test this out locally without hitting Mailgun. The `mailgun` package gives us a very easy way to do this. In the client module, we set the mode to `:test` and provide a path to a file for `mailgun` to write out the JSON representation of our emails.

Let's add those to our client module at `lib/hello_phoenix/mailer.ex`.

```elixir
defmodule HelloPhoenix.Mailer do
  use Mailgun.Client, domain: Application.get_env(:my_app, :mailgun_domain),
                      key: Application.get_env(:my_app, :mailgun_key),
                      mode: :test,
                      test_file_path: "/tmp/mailgun.json"
  . . .
end
```

Let's try this out from `iex`. We'll use `iex -S mix phoenix.server` in order to interact with a running Phoenix application. Once we're in an `iex` session, we can call our welcome email function, passing in the address we want to send the email to.

```console
$ iex -S mix phoenix.server
. . .
iex> HelloPhoenix.Mailer.send_welcome_text_email("us@example.com")
{:ok, "OK"}
```

In test mode, the `send_mail/1` function will always return `{:ok, "OK"}`.

Now, we can see the results in the output file.

```console
$ more /tmp/mailgun.json
{"to":"us@example.com","text":"Welcome to HelloPhoenix!","subject":"Welcome!","from":"Mailgun Sandbox <postmaster@sandbox-our-domain.mailgun.org>"}
```

We can send HTML emails as well. To do this, we can define a new function which uses an `:html` key instead of `:text`. The HTML value we use will need to be a string.

```elixir
def send_welcome_html_email(email_address) do
  send_email to: email_address,
             from: "us@example.com",
             subject: "Welcome!",
             html: "<strong>Welcome to HelloPhoenix</strong>"
end
```

Notice that we have some duplication here in the value of the "from" lines in both functions. We can fix that with a module attribute.

```elixir
defmodule HelloPhoenix.Mailer do
  . . .
  @from "us@example.com"
  . . .
```

If we substitute our module attribute for the string in the `:from` lines, our two functions will look like this.

```elixir
def send_welcome_text_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: "Welcome to HelloPhoenix!"
end

def send_welcome_html_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             html: "<strong>Welcome to HelloPhoenix</strong>"
end
```

When we call the `send_welcome_html_email/1` function, we get almost the same output, with the HTML content instead of the text content.

```console
$ iex -S mix phoenix.server

iex> HelloPhoenix.Mailer.send_welcome_html_email("us@example.com")
{:ok, "OK"}
```

Here's the output in `/tmp/mailgun.json`.

```console
$ more /tmp/mailgun.json
{"to":"them@example.com","subject":"Welcome!","html":"<strong>Welcome to HelloPhoenix Test</strong>","from":"Mailgun Sandbox <postmaster@sandbox-our-domain.mailgun.org>"}
```

For many email uses, it's good to have clients try to render an HTML version first, then fall back to plain text if they are unable to do so. Let's write a new `send_welcome_email/1` function which will supersede the other two welcome email functions. In it, we'll simply use both `:text` and `:html` options. This will produce a multi-part email with the text section separated from the HTML section. Each will appear in the order it is defined in the function.

```elixir
def send_welcome_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: "Welcome to HelloPhoenix!",
             html: "<strong>Welcome to HelloPhoenix</strong>"
end
```

When we call our new function, this is what we get.

```console
$ more /tmp/mailgun.json

{"to":"us@example.com","text":"Welcome to HelloPhoenix!","subject":"Welcome!","html":"<strong>Welcome to HelloPhoenix Test</strong>","from":"Mailgun Sandbox <postmaster@sandbox-our-domain.mailgun.org>"}
```

Let's take our client out of test mode by removing the `:mode` and `:test_file_path` options.

```elixir
defmodule HelloPhoenix.Mailer do
  use Mailgun.Client,
      domain: Application.get_env(:hello_phoenix, :mailgun_domain),
      key: Application.get_env(:hello_phoenix, :mailgun_key)
  . . .
```

When we restart the application and call our `send_welcome_email/1` function, we actually get a response back from Mailgun telling us our email has been queued.

```console
iex> HelloPhoenix.Mailer.send_welcome_email("us@example.com")
{:ok,
 "{\n  \"id\": \"<20150820050046.numbers.more_numbers@sandbox-our-domain.mailgun.org>\",\n  \"message\": \"Queued. Thank you.\"\n}"}
```

Great! Time to check our inbox.

Looking at the original source of our email, we can see that it is indeed a multipart email with two parts. The first is our text email, with a Content-Type of "text/plain". The second is our HTML email with a Content-Type of "text/html".

```
To: them@example.com
From: Mailgun Sandbox
 <postmaster@sandbox-our-domain.mailgun.org>
Subject: Welcome!
Mime-Version: 1.0
Content-Type: multipart/alternative; boundary="ab2eaf529cf8442b93154d6e3d98896e"

--ab2eaf529cf8442b93154d6e3d98896e
Content-Type: text/plain; charset="ascii"
Mime-Version: 1.0
Content-Transfer-Encoding: 7bit

Welcome to HelloPhoenix!
--ab2eaf529cf8442b93154d6e3d98896e
Content-Type: text/html; charset="ascii"
Mime-Version: 1.0
Content-Transfer-Encoding: 7bit

<strong>Welcome to HelloPhoenix Test</strong>
--ab2eaf529cf8442b93154d6e3d98896e--
```

### Tidying Up

What we've written so far is fine, but for a real-world welcome email, we're going to need more than a few words of text or a single HTML tag. With more text or HTML, though, our `send_welcome_email/1` will become messy quite quickly. The solution is private functions which cordon off the complexity behind a descriptive name.

In our `HelloPhoenix.Mailer` module, we can define a private `welcome_text/0` function which uses a heredoc to define a string literal for the text that makes up the body of our email.

```elixir
. . .
defp welcome_text do
  """
  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  """
end
. . .
```

Now we can use it in our `send_welcome_email/1` function.

```elixir
def send_welcome_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: welcome_text,
             html: "<strong>Welcome to HelloPhoenix</strong>"
end
```

If we're going to render anything other than the simplest HTML while still having a readable `send_welcome_email/1` function, using bare HTML strings is going to present problems as well. Rendering templates fixes that, but we need a string value for the `:html` key. The `Phoenix.View.render_to_string/3` function will do just what we need.

```elixir
def send_welcome_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: welcome_text,
             html: Phoenix.View.render_to_string(HelloPhoenix.EmailView, "welcome.html", %{})
end
```

To make this example work, we'll need the same components that we would use to render any template in Phoenix.

First, we'll need a basic `HelloPhoenix.EmailView` defined at `web/views/email_view.ex`.

```elixir
defmodule HelloPhoenix.EmailView do
  use HelloPhoenix.Web, :view
end
```

We'll also need a new `email` directory in `web/templates` with a `welcome.html.eex` template in it.

```html
<div class="jumbotron">
  <h2>Welcome to HelloPhoenix!</h2>
</div>
```

> Note: If we need to use any path or url helpers in our template, we will need to pass the endpoint instead of a connection struct for the first argument. This is because we won't be in the context of a request, so `@conn` won't be available. For example, we will need to write this
```elixir
alias HelloPhoenix
Router.Helpers.page_path(Endpoint, :index)
```
instead of this.
```elixir
Router.Helpers.page_path(@conn, :index)
```

If we have any other values we need to pass into the template, we can pass a map of them as the third argument to `Phoenix.View.render_to_string/3`.

We can put the render call behind a private function as well, just as we did with `welcome_text/0`.

```elixir
. . .
defp welcome_html do
  Phoenix.View.render_to_string(HelloPhoenix.EmailView, "welcome.html", %{})
end
. . .
```

With that our `send_welcome_email/1` function looks much nicer.

```elixir
def send_welcome_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: welcome_text,
             html: welcome_html
end
```

### Sending attachments

Mailgun also lets us send attachments with an email. We'll use the `:attachments` key to tell `mailgun` that we want to include one or more of them. The value we give it needs to be a list of two element maps. One element of each map needs to be the path to a file we want to attach. The other needs to be the filename.

Sending new users a copy of the Phoenix framework logo with their welcome email would look like this.

```elixir
def send_welcome_email(email_address) do
  send_email to: email_address,
             from: @from,
             subject: "Welcome!",
             text: welcome_text,
             html: welcome_html,
             attachments: [%{path: "priv/static/images/phoenix.png", filename: "phoenix.png"}]
end
```

If we put our mailer client back in test mode, restart our application, and call the `send_welcome_email/1` function with our email address, we'll see our attachment at the very end.

```console
more mailgun.json
{"to":"us@example.com","text":"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n","subject":"Welcome!","html":"<div class=\"jumbotron\">\n  <h2>Welcome to HelloPhoenix!</h2>\n</div>","from":"Mailgun Sandbox <postmaster@sandbox-our-domain.mailgun.org>","attachments":[{"path":"priv/static/images/phoenix.png","filename":"phoenix.png"}]}
```

Then we can take the mailer out of test mode and actually send it.
