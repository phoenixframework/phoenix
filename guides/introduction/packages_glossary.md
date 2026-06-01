# Packages Glossary

By default, Phoenix applications depend on several packages with different purposes.
This page is a quick reference of the different packages you may work with as a Phoenix
developer.

The main packages are:

  * [Ecto](https://ecto.hexdocs.pm) - a language integrated query and
    database wrapper

  * [Phoenix](https://phoenix.hexdocs.pm) - the Phoenix web framework
    (these docs)

  * [Phoenix LiveView](https://phoenix-live-view.hexdocs.pm) - build rich,
    real-time user experiences with server-rendered HTML. The LiveView
    project also defines [`Phoenix.Component`](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) and
    [the HEEx template engine](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html#sigil_H/2),
    used for rendering HTML content in both regular and real-time applications

  * [Plug](https://plug.hexdocs.pm) - specification and conveniences for
    building composable modules web applications. This is the package
    responsible for the connection abstraction and the regular request-
    response life-cycle

You will also work with the following:

  * [ExUnit](https://ex-unit.hexdocs.pm) - Elixir's built-in test framework

  * [Gettext](https://gettext.hexdocs.pm) - internationalization and
    localization through [`gettext`](https://www.gnu.org/software/gettext/)

  * [Swoosh](https://swoosh.hexdocs.pm) - a library for composing,
    delivering and testing emails, also used by `mix phx.gen.auth`

When peeking under the covers, you will find these libraries play
an important role in Phoenix applications:

  * [Phoenix HTML](https://phoenix-html.hexdocs.pm) - building blocks
    for working with HTML and forms safely

  * [Phoenix Ecto](https://hex.pm/packages/phoenix_ecto) - plugs and
    protocol implementations for using phoenix with ecto

  * [Phoenix PubSub](https://phoenix-pubsub.hexdocs.pm) - a distributed
    pub/sub system with presence support

When it comes to instrumentation and monitoring, check out:

  * [Phoenix LiveDashboard](https://phoenix-live-dashboard.hexdocs.pm) -
    real-time performance monitoring and debugging tools for Phoenix
    developers

  * [Telemetry Metrics](https://telemetry-metrics.hexdocs.pm) - common
    interface for defining metrics based on Telemetry events
