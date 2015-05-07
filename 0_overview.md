Phoenix is a web development framework written in Elixir which implements the server-side MVC pattern. If you've ever used a similar framework, say Ruby on Rails or Python's Django, many of the concepts will be familiar to you. Phoenix gives you the best of both worlds, high developer productivity _and_ high application performance. It also has some interesting new twists, channels for managing realtime events, pre-compiled templates and the potential for alternative architectures which may make services more manageable from the very beginning of your project.

If you are already familiar with Elixir, great! If not, there are a number of places you can go to learn. You might want to read through the [Elixir guides](http://elixir-lang.org/getting_started/1.html) first. You might also want to look through any of the books, blogs or videos listed in the [Resources Guide](http://www.phoenixframework.org/docs/resources).

The aim of this introductory guide is to present a brief, high level overview of Phoenix, the parts that make it up, and the layers underneath that support it.

### Phoenix

Phoenix is actually the top layer of a multi-layer system designed to be modular and flexible. The other layers are the Elixir middleware project, Plug, and the Erlang web server, Cowboy. Plug and Cowboy are covered in the next sections of this guide.

Phoenix is made up of a number of distinct parts, each with its own purpose and role to play in building a web application. We will cover them all in depth throughout these guides, but here's a quick breakdown.

- The Endpoint
  - handles all aspects of requests up until the beginning of our applications
  - provides a core set of middleware to apply to all requests
  - dispatches requests into designated routers
- The Router
  - parses incoming requests and dispatches to the correct controller/action, passing parameters as needed
  - provides helpers to generate route paths or urls to resources
- Pipelines
  - Allow easy segregation of middleware across different routes
- Controllers
  - provide functions, called *actions*, to handle requests
  - Actions
    - prepare data and pass it into views
    - invoke rendering via views
    - perform redirects
- Views
  - render templates
  - act as a presentation layer
  - define helper functions, available in templates, to decorate raw data
- Templates
  - are what they sound like :)
  - Precompiled & fast
- Channels
  - manage sockets for easy realtime communication
  - analogous to controllers except that they allow bi-directional communication with persistent connections
- PubSub
  - Underlies the channel layer and allows *topics* to be subscribed to
  - Abstracts the underlying pubsub adapter for third-party pubsub integration

### Plug

[Plug](http://hexdocs.pm/plug/) is Elixir's web middleware layer. Conceptually, it shares a lot with other middleware layers like Rack for Ruby or WSGI for Python. Plugs are reusable modules that share the same very small, very regular public api. They provide discrete behaviors - like request header parsing or logging. Because the Plug api is so consistent, they can be stacked and executed in a set order, like a pipeline. They can also be re-used within a project or across projects.

Plugs can be written to handle almost anything, from authentication to parameter pre-processing, and even rendering.

Phoenix takes great advantage of Plug in general - the router and controllers especially so.

One of the most important things about Plug, is that it provides adapters to HTTP servers which will ultimately deliver application content to your users. Currently, Plug only provides an adapter to Cowboy, which we will talk about next, but there are plans to provide adapters for other servers in the future.

Links to more in-depth information on Plug can be found in the [Resources Guide](http://www.phoenixframework.org/docs/resources).

### Cowboy

Cowboy is an HTTP server written in Erlang by Loïc Hoguin of [99s](http://ninenines.eu/). Cowboy is built in a modular way on top of Ranch, Bullet, and Sheriff. This is how 99s describes them.

- Cowboy is a small, fast, modular HTTP server supporting Websockets, SPDY and more.

- Ranch is a socket acceptor pool for TCP protocols. It is also a standalone library for building networked applications.

- Bullet is a simple, reliable, efficient streaming library.

- Sheriff uses parse transforms for type based validation. Sheriff also validates data dynamically using Erlang's type system with no extra code required.

Cowboy has fantastic documentation. The [Guides](http://ninenines.eu/docs/en/cowboy/HEAD/guide/) are especially helpful. Learning more about Cowboy will surely help you to understand Phoenix more fully.

Cowboy has its own section of links in the [Resources Guide](http://www.phoenixframework.org/docs/resources).


### System Dependencies

There are a number of dependencies external to Phoenix which we will encounter as we work our way through these guides. Elixir and Erlang are hard dependencies, meaning that we won't be able to work with Phoenix at all unless we have them installed. The rest may not prevent us from getting started if we don't have them, but their absence may lead to errors that prevent us from moving forward. Simply installing these dependencies may save us from confusion and frustration later on.

Let's take a look at each of them now.

- Elixir

  Phoenix is written in Elixir, and our application code will also be written in Elixir. In order to do any work with Phoenix, we need Elixir installed on our system. The Elixir site itself has great [installation instructions](http://elixir-lang.org/install.html).

- Erlang
  
  Elixir source code compiles to Erlang byte code which runs on the Erlang Virtual Machine. That means we must have Erlang installed on our system - in addition to Elixir - in order to work with Phoenix. The Elixir site also has [Erlang installation instructions](http://elixir-lang.org/install.html#installing-erlang).

- node.js

  Node is an optional dependency. Phoenix will use brunch.io to compile static assets (javascript, css, etc), by default. Brunch.io uses the node package manager (npm) to install its dependencies, and npm requires node.js.

  If we don't have any static assets, or we want to use another build tool, we can pass the `--no-brunch` flag when creating a new application and node won't be required at all.

- PostgreSQL

  PostgreSQL is a relational database server. Phoenix configures applications to use it by default, but we can switch to MySQL by passing the `--database mysql` flag when creating a new application.

  When we work with Ecto models in these guides, we will use PostgreSQL and the Postgrex adapter for it. In order to follow along with the examples, we will need to install PostgreSQL on our system. The PostgreSQL wiki has [installation guides](https://wiki.postgresql.org/wiki/Detailed_installation_guides) for a number of different systems.

- inotify-tools

  This is a Linux-only filesystem watcher that Phoenix uses for live code reloading. (Mac OS X or Windows users can safely ignore it.)

  Linux users need to install this dependency. Please consult the [inotify-tools wiki](https://github.com/rvoicilas/inotify-tools/wiki) for distribution-specific installation instructions.
