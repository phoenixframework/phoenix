# Packages Glossary

By default, Phoenix applications depend on several packages with different purposes.
This page is a quick reference of the different packages you may work with as a Phoenix
developer.

The main packages are:

  * [Ecto](https://hexdocs.pm/ecto) - a language integrated query and
    database wrapper

  * [Phoenix](https://hexdocs.pm/phoenix) - the Phoenix web framework
    (these docs)

  * [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - build rich,
    real-time user experiences with server-rendered HTML. The LiveView
    project also defines [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) and
    [the HEEx template engine](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2),
    used for rendering HTML content in both regular and real-time applications

  * [Plug](https://hexdocs.pm/plug) - specification and conveniences for
    building composable modules web applications. This is the package
    responsible for the connection abstraction and the regular request-
    response life-cycle

You will also work with the following:

  * [ExUnit](https://hexdocs.pm/ex_unit) - Elixir's built-in test framework

  * [Gettext](https://hexdocs.pm/gettext) - internationalization and
    localization through [`gettext`](https://www.gnu.org/software/gettext/)

  * [Swoosh](https://hexdocs.pm/swoosh) - a library for composing,
    delivering and testing emails, also used by `mix phx.gen.auth`

When peeking under the covers, you will find these libraries play
an important role in Phoenix applications:

  * [Phoenix HTML](https://hexdocs.pm/phoenix_html) - building blocks
    for working with HTML and forms safely

  * [Phoenix Ecto](https://hex.pm/packages/phoenix_ecto) - plugs and
    protocol implementations for using phoenix with ecto

  * [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub) - a distributed
    pub/sub system with presence support

When it comes to instrumentation and monitoring, check out:

  * [Phoenix LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) -
    real-time performance monitoring and debugging tools for Phoenix
    developers

  * [Telemetry Metrics](https://hexdocs.pm/telemetry_metrics) - common
    interface for defining metrics based on Telemetry events
