# Overview

Phoenix is a web development framework written in Elixir which implements the server-side MVC pattern. Many of its components and concepts will seem familiar to those of us with experience in other web frameworks like Ruby on Rails or Python's Django.

Phoenix provides the best of both worlds - high developer productivity _and_ high application performance. It also has some interesting new twists like channels for implementing realtime features and pre-compiled templates for blazing speed.

If you are already familiar with Elixir, great! If not, there are a number of places to learn. The [Elixir guides](https://elixir-lang.org/getting-started/introduction.html) are a great place to start. We also have a list of helpful resources in the [Learning Elixir and Erlang Guide](http://www.phoenixframework.org/docs/learning-elixir-and-erlang).

The aim of this introductory guide is to present a brief, high-level overview of Phoenix, the parts that make it up, and the layers underneath that support it.

If you would prefer to read these guides as an EPUB [click here!](Phoenix.epub)

### Phoenix

Phoenix is made up of a number of distinct parts, each with its own purpose and role to play in building a web application. We will cover them all in depth throughout these guides, but here's a quick breakdown.

 - [Endpoint](endpoint.html)
    - the start and end of the request lifecycle
    - handles all aspects of requests up until the point where the router takes over
    - provides a core set of plugs to apply to all requests
    - dispatches requests into a designated router
 - [Router](routing.html)
    - parses incoming requests and dispatches them to the correct controller/action, passing parameters as needed
    - provides helpers to generate route paths or urls to resources
    - defines named pipelines through which we may pass our requests
    - Pipelines - allow easy application of groups of plugs to a set of routes
 - [Controllers](controllers.html)
    - provide functions, called *actions*, to handle requests
    - actions:
        - prepare data and pass it into views
        - invoke rendering via views
        - perform redirects
 - [Views](views.html)
    - render templates
    - act as a presentation layer
    - define helper functions, available in templates, to decorate data for presentation
 - [Templates](templates.html)
    - are what they sound like :)
    - are precompiled and fast
 - [Channels](channels.html)
    - manage sockets for easy realtime communication
    - are analogous to controllers except that they allow bi-directional communication with persistent connections
 - PubSub
    - underlies the channel layer and allows clients to subscribe to *topics*
    - abstracts the underlying pubsub adapter for third-party pubsub integration

## Phoenix Layers

We just covered the internal parts that make up Phoenix, but its important to remember Phoenix itself is actually the top layer of a multi-layer system designed to be modular and flexible. The other layers include Cowboy, Plug, and Ecto.

### Cowboy

By default, the web server used by Phoenix (and Plug) is Cowboy. It is uncommon to interface with Cowboy directly when using Phoenix. If you do require using Cowboy directly, please refer to the [Cowboy documentation](https://ninenines.eu/docs/en/cowboy/1.0/guide/).

### Plug

[Plug](https://hexdocs.pm/plug/) is a specification for constructing composable modules to build web applications. Plugs are reusable modules or functions built to that specification. They provide discrete behaviors - like request header parsing or logging. Because the Plug API is small and consistent, plugs can be defined and executed in a set order, like a pipeline. They can also be re-used within a project or across projects.

Plugs can be written to handle almost anything, from authentication to parameter pre-processing, and even rendering.

Phoenix takes great advantage of Plug in general - the router and controllers especially so.

One of the most important things about Plug is that it provides adapters to HTTP servers which will ultimately deliver application content to our users. Currently Plug only provides an adapter for [Cowboy](https://github.com/ninenines/cowboy), a web server written in Erlang by Loïc Hoguin of [99s](http://ninenines.eu/).

Have a look at the [Plug Guide](plug.html) for more details.

### Ecto

[Ecto](https://hexdocs.pm/ecto) is a language integrated query composition tool and database wrapper for Elixir. With Ecto, we can read and write to different databases, model our domain data, write complex queries in a type-safe way, protect against attack vectors - including SQL injection, and much more.

Ecto is built around four main abstractions:

* Repo - A repository represents a connection to an individual database. Every database operation is done via the repository.

* Schema - Schemas are our data definitions. They define table names and fields as well as each field's type. Schemas also define associations - the relationships between our resources.

* Query - Queries tie both schemas and repositories together, allowing us to elegantly retrieve data from the repository and cast it into the schemas themselves.

* Changeset - Changesets declare transformations we need to perform on our data before our application can use it. These include type casting, validations, and more.

A new Phoenix application will use Ecto with PostgreSQL storage by default.

## A Note about these guides
If you find an issue with the guides or would like to help improve these guides please checkout the [Phoenix Guides](https://github.com/phoenixframework/phoenix_guides/) github. Issues and Pull Requests are happily accepted!
