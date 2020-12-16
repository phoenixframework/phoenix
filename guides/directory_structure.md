# Directory structure

> **Requirement**: This guide expects that you have gone through the introductory guides and got a Phoenix application up and running.

When we use `mix phx.new` to generate a new Phoenix application, it builds a top-level directory structure like this:

```console
├── _build
├── assets
├── config
├── deps
├── lib
│   ├── hello
│   │   └── hello.ex
│   └── hello_web
│       └── hello_web.ex
├── priv
└── test
```

We will go over those directories one by one:

  * `_build` - a directory created by the `mix` command line tool that ships as part of Elixir that holds all compilation artefacts. As we have seen in "Up and Running", `mix` is the main interface to your application. We use Mix to compile our code, create databases, run our server, and more. This directory must not be checked into version control and it can be removed at any time. Removing it will force Mix to rebuild your application from scratch

  * `assets` - a directory that keeps everything related to front-end assets, such as JavaScript, CSS, static images and more. It is typically handled by the `npm` tool. Phoenix developers typically only need to run `npm install` inside the assets directory. Everything else is managed by Phoenix

  * `config` - a directory that holds your project configuration. The `config/config.exs` file is the main entry point for your configuration. At the end of the `config/config.exs`, it imports environment specific configuration, which can be found in `config/dev.exs`, `config/test.exs`, and `config/prod.exs`

  * `deps` - a directory with all of our Mix dependencies. You can find all dependencies listed in the `mix.exs` file, inside the `def deps do` function definition. This directory must not be checked into version control and it can be removed at any time. Removing it will force Mix to download all deps from scratch

  * `lib` - a directory that holds your application source code. This directory is broken into two subdirectories, `lib/hello` and `lib/hello_web`. The `lib/hello` directory will be responsible to host all of your business logic and business domain. It typically interacts directly with the database - it is the "Model" in Model-View-Controller (MVC) architecture. `lib/hello_web` is responsible for exposing your business domain to the world, in this case, through a web application. It holds both the View and Controller from MVC. We will discuss the contents of these directories with more detail in the next sections

  * `priv` - a directory that keeps all assets that are necessary in production but are not directly part of your source code. You typically keep database scripts, translation files, and more in here

  * `test` - a directory with all of our application tests. It often mirrors the same structure found in `lib`

## The lib/hello directory

The `lib/hello` directory hosts all of your business domain. Since our project does not have any business logic yet, the directory is mostly empty. You will only find two files:

```console
lib/hello
├── application.ex
└── repo.ex
```

The `lib/hello/application.ex` file defines an Elixir application named `Hello.Application`. That's because at the end of the day Phoenix applications are simply Elixir applications. The `Hello.Application` module defines which services are part of our application:

```elixir
children = [
  # Start the Ecto repository
  Hello.Repo,
  # Start the Telemetry supervisor
  HelloWeb.Telemetry,
  # Start the PubSub system
  {Phoenix.PubSub, name: Hello.PubSub},
  # Start the Endpoint (http/https)
  HelloWeb.Endpoint
  # Start a worker by calling: Hello.Worker.start_link(arg)
  # {Hello.Worker, arg}
]
```

If it is your first time with Phoenix, you don't need to worry about the details right now. For now, suffice it to say our application starts a database repository, a pubsub system for sharing messages across processes and nodes, and the application endpoint, which effectively serves HTTP requests. These services are started in the order they are defined and, whenever shutting down your application, they are stopped in the reverse order.

You can learn more about applications in [Elixir's official docs for Application](https://hexdocs.pm/elixir/Application.html).

In the same `lib/hello` directory, we will find a `lib/hello/repo.ex`. It defines a `Hello.Repo` module which is our main interface to the database. If you are using Postgres (the default), you will see something like this:

```elixir
defmodule Hello.Repo do
  use Ecto.Repo,
    otp_app: :hello,
    adapter: Ecto.Adapters.Postgres
end
```

And that's it for now. As you work on your project, we will add files and modules to this directory.

## The lib/hello_web directory

The `lib/hello_web` directory holds the web-related parts of our application. It looks like this when expanded:

```console
lib/hello_web
├── channels
│   └── user_socket.ex
├── controllers
│   └── page_controller.ex
├── templates
│   ├── layout
│   │   └── app.html.eex
│   └── page
│       └── index.html.eex
├── views
│   ├── error_helpers.ex
│   ├── error_view.ex
│   ├── layout_view.ex
│   └── page_view.ex
├── endpoint.ex
├── gettext.ex
├── router.ex
└── telemetry.ex
```

All of the files which are currently in the `controllers`, `templates`, and `views` directories are there to create the "Welcome to Phoenix!" page we saw in the "Up and running" guide. 
The `channels` directory is where we will add code related to building real-time Phoenix applications.

By looking at `templates` and `views` directories, we can see Phoenix provides features for handling layouts and error pages out of the box.

Besides the directories mentioned, `lib/hello_web` has four files at its root. `lib/hello_web/endpoint.ex` is the entry-point for HTTP requests. Once the browser accesses `http://localhost:4000`, the endpoint starts processing the data, eventually leading to the router, which is defined in `lib/hello_web/router.ex`. The router defines the rules to dispatch requests to "controllers", which then uses "views" and "templates" to render HTML pages back to clients. We explore these layers in length in other guides, starting with the "Request life-cycle" guide coming next.

Through _telemetry_, Phoenix is able to collect metrics and send monitoring events of your application. The `lib/hello_web/telemetry.ex` file defines the supervisor responsible for managing the telemetry processes. You can find more information on this topic in the [Telemetry guide](telemetry.html).

Finally, there is a `lib/hello_web/gettext.ex` file which provides internationalization through [Gettext](https://hexdocs.pm/gettext/Gettext.html). If you are not worried about internationalization, you can safely skip this file and its contents.
