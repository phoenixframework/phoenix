Phoenix is a web development framework written in Elixir which implements the server-side MVC pattern. Many of its components and concepts will seem familiar to those of us with experience in other web frameworks like Ruby on Rails or Python's Django.

Phoenix provides the best of both worlds, high developer productivity _and_ high application performance. It also has some interesting new twists like channels for implementing realtime features and pre-compiled templates for blazing speed.

If you are already familiar with Elixir, great! If not, there are a number of places to learn. The [Elixir guides](http://elixir-lang.org/getting_started/1.html) are a great place to start. We also have a list of helpful resources in the [Learning Elixir Guide](http://www.phoenixframework.org/docs/learning-elixir).

The aim of this introductory guide is to present a brief, high-level overview of Phoenix, the parts that make it up, and the layers underneath that support it.

### Phoenix

Phoenix is actually the top layer of a multi-layer system designed to be modular and flexible. The other layers are the Elixir project, Plug, and the Erlang web server, Cowboy. We will cover Plug and Cowboy in the sections just after Phoenix in this overview.

Phoenix is made up of a number of distinct parts, each with its own purpose and role to play in building a web application. We will cover them all in depth throughout these guides, but here's a quick breakdown.

- The Endpoint
  - handles all aspects of requests up until the point where the router take over
  - provides a core set of plugs to apply to all requests
  - dispatches requests into a designated router
- The Router
  - parses incoming requests and dispatches to the correct controller/action, passing parameters as needed
  - provides helpers to generate route paths or urls to resources
  - defines named pipelines through which we may pass our requests
  - Pipelines
    - allow easy application of groups of plugs to a set of routes
- Controllers
  - provide functions, called *actions*, to handle requests
  - Actions
    - prepare data and pass it into views
    - invoke rendering via views
    - perform redirects
- Views
  - render templates
  - act as a presentation layer
  - define helper functions, available in templates, to decorate data for presentation
- Templates
  - are what they sound like :)
  - are precompiled and fast
- Channels
  - manage sockets for easy realtime communication
  - are analogous to controllers except that they allow bi-directional communication with persistent connections
- PubSub
  - underlies the channel layer and allows clients to subscribe to *topics*
  - abstracts the underlying pubsub adapter for third-party pubsub integration

### Plug

[Plug](http://hexdocs.pm/plug/) is a specification for constructing composable modules to build web applications. Plugs are reusable modules or functions built to that specification. They provide discrete behaviors - like request header parsing or logging. Because the Plug api is small and consistent, plugs can be stacked and executed in a set order, like a pipeline. They can also be re-used within a project or across projects.

Plugs can be written to handle almost anything, from authentication to parameter pre-processing, and even rendering.

Phoenix takes great advantage of Plug in general - the router and controllers especially so.

One of the most important things about Plug is that it provides adapters to HTTP servers which will ultimately deliver application content to our users. Currently, Plug only provides an adapter for Cowboy, which we will talk about next, but there are plans to provide adapters for other servers in the future.

Have a look at the [Plug Guide](http://www.phoenixframework.org/docs/understanding-plug) for more details.

### Cowboy

Cowboy is an HTTP server written in Erlang by Loïc Hoguin of [99s](http://ninenines.eu/). Cowboy is built in a modular way on top of Ranch, Bullet, and Sheriff. This is how 99s describes them.

- Cowboy is a small, fast, modular HTTP server supporting Websockets, SPDY and more.

- Ranch is a socket acceptor pool for TCP protocols. It is also a standalone library for building networked applications.

- Bullet is a simple, reliable, efficient streaming library.

- Sheriff uses parse transforms for type based validation. Sheriff also validates data dynamically using Erlang's type system with no extra code required.

Cowboy has fantastic documentation. The [Guides](http://ninenines.eu/docs/en/cowboy/HEAD/guide/) are especially helpful. Learning more about Cowboy will surely help you to understand Phoenix more fully.

Cowboy has its own section of links in the [Resources Guide](http://www.phoenixframework.org/docs/resources#section-cowboy).
