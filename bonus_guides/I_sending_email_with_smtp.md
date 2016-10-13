# Sending Email with SMTP

Sending email from a Phoenix application is easy with SMTP and community
libraries.

First you will need an SMTP service provider, such as [Amazon Simple Email
Service](https://aws.amazon.com/ses/), [Mailgun](https://www.mailgun.com/), or
[SendGrid](https://sendgrid.com/). Go ahead and sign up for one, often there
is a free tier that can be used to try out the service.

Once we have a provider, we'll need to add
[`bamboo`](https://github.com/thoughtbot/bamboo) and
[`bamboo_smtp`](https://github.com/fewlinesco/bamboo_smtp) as dependencies to
our project. We'll do that in the `deps/0` function in `mix.exs`.

```elixir
defp deps do
  [{:phoenix, "~> 1.1.0"},
   {:phoenix_ecto, "~> 2.0"},
   {:postgrex, ">= 0.0.0"},
   {:phoenix_html, "~> 2.3"},
   {:phoenix_live_reload, "~> 1.0", only: :dev},
   {:cowboy, "~> 1.0"},
   {:bamboo, "~> 0.5"},
   {:bamboo_smtp, "~> 0.1"}]
end
```

Next, we'll need to run `mix deps.get` to bring the two new packages into our
application.

Once the packages have been fetched add the `:bamboo` application to our
`application/0` function in `mix.exs`.

```elixir
def application do
  [mod: {MyApp, []},
    applications: [:phoenix, :phoenix_html, :cowboy, :logger, :gettext,
                  :phoenix_ecto, :postgrex, :bamboo]]
end
```


### Configuration

We'll also need to add our SMTP details to `config/config.ex`. These will be
provided by the SMTP service you signed up to, so check your account on there.

For security reasons, it's important to not commit these values to a public
source code repository. There are a couple of ways we can accomplish this.

Set up environment variables for our `SMTP_USERNAME` and `SMTP_PASSWORD`. With
the environment variables set, we can reference them in our
`config/config.exs` file.

Be sure to replace `:my_app` with the atom name of your application.

```elixir
# In your config/config.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: "smtp.domain",
  port: 1025,
  username: SYSTEM.get_env("SMTP_USERNAME"),
  password: SYSTEM.get_env("SMTP_PASSWORD"),
  tls: :if_available, # can be `:always` or `:never`
  ssl: false, # can be `true`
  retries: 1
```

These variables will need to be set on the production servers, as well
as on our development machines. Please see the [Deployment Introduction
Guide](http://www.phoenixframework.org/docs/deployment) for more information.

### The Mailer and Emails

In order for our application to send emails, we'll need a mailer module. Let's
define one here `lib/app/mailer.ex`. When we `use` the `Bamboo.Mailer` module
in the second line, we pass in the atom name of our application.

```elixir
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end
```

We'll also need a new view module for emails. We can define this in
`web/views/email_view.ex`.

```elixir
defmodule MyApp.EmailView do
  use MyApp.Web, :view
end
```

Lastly we need another module that will contain our emails, which we can
define in `lib/email.ex`.

```elixir
defmodule Email do
  use Bamboo.Phoenix, view: MyApp.EmailView
end
```

With this in place, we can start creating our custom email functions. Web
applications may send any number of different types of emails - welcome emails
after signup, password confirmations, activity notifications - the list goes
on. For each type of email, we'll define a new function which will call
`new_email/1` in order to build the email.

Let's say we want to send a welcome email to new users formatted as plain
text. We'll need to know who to send the email to, as well as the "from"
address, subject, and body of the email. This will be sent as a plain text
email because we've specified the `:text` option.

```elixir
defmodule MyApp.Email do
  use Bamboo.Phoenix, view: MyApp.EmailView

  def welcome_text_email(email_address) do
    new_email
    |> to(email_address)
    |> from("us@example.com")
    |> subject("Welcome!")
    |> text_body("Welcome to MyApp!")
  end
end
```

Building the email is as easy as invoking the function with an email address.
Once we have the email we can then send it by piping into a delivery function
from our Mailer module. We can do this from wherever we want to in our
application.

```elixir
MyApp.Email.welcome_text_email("us@example.com") |> Mailer.deliver_now
```

We can also deliver emails asyncronously in the background rather than waiting
for the email to be be sent.

```elixir
MyApp.Email.welcome_text_email("us@example.com") |> Mailer.deliver_later
```

See the Bamboo [README](https://github.com/thoughtbot/bamboo#delivering-emails-in-the-background)
for more information.

#### HTML Emails

We can build HTML emails as well. To do this, we can define a new function
which builds the text email, and then pipes it into the `html_body/2` function
to add the HTML body content.

```elixir
defmodule MyApp.Email do
  use Bamboo.Phoenix, view: MyApp.EmailView

  def welcome_text_email(email_address) do
    new_email()
    |> to(email_address)
    |> from("us@example.com")
    |> subject("Welcome!")
    |> text_body("Welcome to MyApp!")
  end

  def welcome_html_email(email_address) do
    email_address
    |> welcome_text_email()
    |> html_body("<strong>Welcome<strong> to MyApp!")
  end
end
```

When we call the `welcome_html_email/1` function we get a multipart email that
has both text and HTML content. Clients will try to render an HTML version
first, then fall back to plain text if they are unable to do so.


### Using Views

What we've written so far is fine, but for a real-world welcome email, we're
going to need more than a few words of text or a single HTML tag. With more
text or HTML, though, our email functions will become large and unwieldy quite
quickly. The solution is to reuse the Phoenix view functionality to store the
email formatting and content elsewhere.

In our app's layout template directory we can create two new layouts, one for
HTML emails, one for text emails.

`web/templates/layout/email.html` could look like this:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width">
  </head>
  <body>
    <p>Hello!</p>
    <%= render @view_module, @view_template, assigns %>
    <p>- The MyApp Team.</p>
  </body>
</html>
```

`web/templates/layout/email.text` could look like this:

```
Hello!

<%= render @view_module, @view_template, assigns %>

- The MyApp Team.
```

Once we have these templates we can use the `put_text_layout/2` and
`put_html_layout/2` functions to wrap the content of our emails with the
layouts.

```elixir
defmodule MyApp.Email do
  use Bamboo.Phoenix, view: MyApp.EmailView

  def welcome_text_email(email_address) do
    new_email()
    |> to(email_address)
    |> from("us@example.com")
    |> subject("Welcome!")
    |> text_body("Welcome to MyApp!")
    |> put_text_layout({MyApp.LayoutView, "email.text"})
  end

  def welcome_html_email(email_address) do
    email_address
    |> welcome_text_email()
    |> html_body("<strong>Welcome<strong> to MyApp!")
    |> put_html_layout({MyApp.LayoutView, "email.html"})
  end
end
```

The process for moving the email content to a template is similar. Again we
create two new templates, one for text, one for HTML.

`web/templates/email/welcome.html` could look like this:

```html
<p>
  <strong>Welcome<strong> to MyApp!
</p>
```

`web/templates/email/welcome.text` could look like this:

```
Welcome to MyApp!
```

And then we would replace the calls to `text_body/2` and `html_body/2` with a
call to `render/2`.

```elixir
defmodule MyApp.Email do
  use Bamboo.Phoenix, view: MyApp.EmailView

  def welcome_text_email(email_address) do
    new_email()
    |> to(email_address)
    |> from("us@example.com")
    |> subject("Welcome!")
    |> put_text_layout({MyApp.LayoutView, "email.text"})
    |> render("welcome.text")
  end

  def welcome_html_email(email_address) do
    email_address
    |> welcome_text_email()
    |> put_html_layout({MyApp.LayoutView, "email.html"})
    |> render("welcome.html")
  end
end
```

Now all our markup has been moved to templates, and our email building
functions are nice and simple!

Lastly, if we wanted variable data in our templates we would just use
assignment as usual with the view render function.

`web/templates/email/welcome.html` could look like this:

```html
<p>
  <strong>Welcome<strong> to MyApp!
</p>
<p>
  Your email address is <%= @email_address %>
</p>
```

```elixir
defmodule MyApp.Email do
  use Bamboo.Phoenix, view: MyApp.EmailView

  def welcome_text_email(email_address) do
    new_email()
    |> to(email_address)
    |> from("us@example.com")
    |> subject("Welcome!")
    |> put_text_layout({MyApp.LayoutView, "email.text"})
    |> render("welcome.text")
  end

  def welcome_html_email(email_address) do
    email_address
    |> welcome_text_email()
    |> put_html_layout({MyApp.LayoutView, "email.html"})
    |> render("welcome.html", email_address: email_address) # <= Assignments
  end
end
```

### Further Information

To learn more about using the Bamboo email library see the [Bamboo
documentation](https://github.com/thoughtbot/bamboo#readme).
