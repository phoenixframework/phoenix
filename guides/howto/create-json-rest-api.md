# Create a JSON REST API

To use the Phoenix Framework to build a JSON REST API backend all we need is to generate a Phoenix application without the HTML and Live generators, and then use the JSON generator to create all the necessary scaffolding.

This guide will be a step by step on how to build our first API project with Phoenix.


## The JSON REST API

For this guide let's create a simple JSON REST API to store our favourite links, that will support all the CRUD (Create, Read, Update, Delete) operations out of the box.

The Links REST API doesn't need to send emails, support internationalization or serve assets, but we will want to have the dashboard available during development.


## The Phoenix Generators

Let's check which `--no-*` flags we need to use to not generate the scaffolding that isn't necessary on our Phoenix application for the REST API.

From your terminal run:

```console
mix help phx.new | grep '\-\-no' -
```

The output should contain the following:

```text
  • --no-assets - do not generate the assets folder. When choosing this
  • --no-ecto - do not generate Ecto files
  • --no-html - do not generate HTML views
  • --no-gettext - do not generate gettext files
  • --no-dashboard - do not include Phoenix.LiveDashboard
  • --no-live - comment out LiveView socket setup in assets/js/app.js and
    also on the endpoint (the latter also requires --no-dashboard)
  • --no-mailer - do not generate Swoosh mailer files
```

The `--no-html` and `--no-live` are the obvious ones we want to use when creating any Phoenix application for a REST API in order to leave out all the unnecessary scaffolding that otherwise would be generated for us, while `--no-ecto` will probably be the only one we may not want to use, unless we are using a database not supported by Ecto.

For our Links REST API we will need a SQL Database to store the links, therefore `--no-ecto` cannot be used on our command, but we will want to use the `--no-assets`, `--no-gettext` and `--no-mailer` in addition to the always necessary `--no-html` and `--no-live`.

Bear in mind that nothing stops you to have a backend that supports simultaneously the REST API and a Web App (HTML, assets, internationalization and sockets).


## Creating the Phoenix Application

To create a REST API we need to first create a Phoenix application without using the unnecessary generators.

First, run this command:

```console
mix phx.new links --no-assets --no-html --no-gettext --no-live --no-mailer
```

> **NOTE:** If we needed to support internationalization then we wouldn't have used `--no-gettext` in the command, and if we needed to send emails we also had to remove `--no-mailer`.

Reply `Y` when prompted for:

```console
Fetch and install dependencies? [Yn] Y
```

After all the dependencies have been fetched and compiled we will get our prompt back.

Now, we need to go inside the `links` folder:

```console
cd links
```

Then we need to configure our database in `config/dev.exs` and run:

```console
mix ecto.create
```

Optionally, we can track our progress with Git in order to see the changes applied
by the generators when creating the REST API.

```console
git init
git add -A
git commit -m 'Created the Phoenix application'
```

### Creating the JSON REST API

Now, we can finally create the REST API with:

```console
mix phx.gen.json Urls Url urls link:string title:string
```

Next, we need to add the `/url` resource to our `:api` scope in `lib/links_web/router.ex`:

```elixir
scope "/api", LinksWeb do
  pipe_through :api
  resources "/urls", UrlController, except: [:new, :edit]
end
```

Then we need to update our repository by running migrations:

```console
mix ecto.migrate
```

Finally, we can use Git to see what changes were made by the generators:

```console
git status -u
```

The output should look similar to this:

```console
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
   modified:   lib/links_web/router.ex

Untracked files:
  (use "git add <file>..." to include in what will be committed)
   lib/links/urls.ex
   lib/links/urls/url.ex
   lib/links_web/controllers/fallback_controller.ex
   lib/links_web/controllers/url_controller.ex
   lib/links_web/views/changeset_view.ex
   lib/links_web/views/url_view.ex
   priv/repo/migrations/20220510194408_create_urls.exs
   test/links/urls_test.exs
   test/links_web/controllers/url_controller_test.exs
   test/support/fixtures/urls_fixtures.ex
```

Now, we have some new files to handle and test all the REST API CRUD operations out of the box for us. Go ahead and inspect each of them to get familiar with how Phoenix does it, and feel free to customize as you see fit.


### Trying out the JSON REST API

We will start the Phoenix server and execute some `cURL` requests to exercise all supported CRUD operations.

First, we need to start the server:

```console
mix phx.server
```

Next, let's make a smoke test to check our REST API is working with:

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

We didn't get any data because we haven't populated the database with any yet.

#### The CRUD Operations

Let's add some links:

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
