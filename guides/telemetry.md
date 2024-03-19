# Telemetry

In this guide, we will show you how to instrument and report
on `:telemetry` events in your Phoenix application.

> `te·lem·e·try` - the process of recording and transmitting
the readings of an instrument.

As you follow along with this guide, we will introduce you to
the core concepts of Telemetry, you will initialize a
reporter to capture your application's events as they occur,
and we will guide you through the steps to properly
instrument your own functions using `:telemetry`. Let's take
a closer look at how Telemetry works in your application.

## Overview

The `[:telemetry]` library allows you to emit events at various stages of an application's lifecycle. You can then respond to these events by, among other things, aggregating them as metrics and sending the metrics data to a reporting destination.

Telemetry stores events by their name in an ETS table, along with the handler for each event. Then, when a given event is executed, Telemetry looks up its handler and invokes it.

Phoenix's Telemetry tooling provides you with a supervisor that uses `Telemetry.Metrics` to define the list of Telemetry events to handle and how to handle those events, i.e. how to structure them as a certain type of metric. This supervisor works together with Telemetry reporters to respond to the specified Telemetry events by aggregating them as the appropriate metric and sending them to the correct reporting destination.

## The Telemetry supervisor

Since v1.5, new Phoenix applications are generated with a
Telemetry supervisor. This module is responsible for
managing the lifecycle of your Telemetry processes. It also
defines a `metrics/0` function, which returns a list of
[`Telemetry.Metrics`](https://hexdocs.pm/telemetry_metrics)
that you define for your application.

By default, the supervisor also starts
[`:telemetry_poller`](https://hexdocs.pm/telemetry_poller).
By simply adding `:telemetry_poller` as a dependency, you
can receive VM-related events on a specified interval.

If you are coming from an older version of Phoenix, install
the `:telemetry_metrics` and `:telemetry_poller` packages:

```elixir
{:telemetry_metrics, "~> 1.0"},
{:telemetry_poller, "~> 1.0"}
```

and create your Telemetry supervisor at
`lib/my_app_web/telemetry.ex`:

```elixir
# lib/my_app_web/telemetry.ex
defmodule MyAppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MyApp, :count_users, []}
    ]
  end
end
```

Make sure to replace MyApp by your actual application name.

Then add to your main application's supervision tree
(usually in `lib/my_app/application.ex`):

```elixir
children = [
  MyAppWeb.Telemetry,
  MyApp.Repo,
  MyAppWeb.Endpoint,
  ...
]
```

## Telemetry Events

Many Elixir libraries (including Phoenix) are already using
the [`:telemetry`](https://hexdocs.pm/telemetry) package as a
way to give users more insight into the behavior of their
applications, by emitting events at key moments in the
application lifecycle.

A Telemetry event is made up of the following:

  * `name` - A string (e.g. `"my_app.worker.stop"`) or a
    list of atoms that uniquely identifies the event.

  * `measurements` - A map of atom keys (e.g. `:duration`)
    and numeric values.

  * `metadata` - A map of key-value pairs that can be used
    for tagging metrics.

### A Phoenix Example

Here is an example of an event from your endpoint:

* `[:phoenix, :endpoint, :stop]` - dispatched by
  `Plug.Telemetry`, one of the default plugs in your endpoint, whenever the response is
  sent

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t}`

This means that after each request, `Plug`, via `:telemetry`,
will emit a "stop" event, with a measurement of how long it
took to get the response:

```elixir
:telemetry.execute([:phoenix, :endpoint, :stop], %{duration: duration}, %{conn: conn})
```

### Phoenix Telemetry Events

A full list of all Phoenix telemetry events can be found in `Phoenix.Logger`

## Metrics

> Metrics are aggregations of Telemetry events with a
> specific name, providing a view of the system's behaviour
> over time.
>
> ― `Telemetry.Metrics`

The Telemetry.Metrics package provides a common interface
for defining metrics. It exposes a set of [five metric type functions](https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-metrics) that are responsible for structuring a given Telemetry event as a particular measurement.

The package does not perform any aggregation of the measurements itself. Instead, it provides a reporter with the Telemetry event-as-measurement definition and the reporter uses that definition to perform aggregations and report them.

We will discuss
reporters in the next section.

Let's take a look at some examples.

Using `Telemetry.Metrics`, you can define a counter metric,
which counts how many HTTP requests were completed:

```elixir
Telemetry.Metrics.counter("phoenix.endpoint.stop.duration")
```

or you could use a distribution metric to see how many
requests were completed in particular time buckets:

```elixir
Telemetry.Metrics.distribution("phoenix.endpoint.stop.duration")
```

This ability to introspect HTTP requests is really powerful --
and this is but one of _many_ telemetry events emitted by
the Phoenix framework! We'll discuss more of these events,
as well as specific patterns for extracting valuable data
from Phoenix/Plug events in the
[Phoenix Metrics](#phoenix-metrics) section later in this
guide.

> The full list of `:telemetry` events emitted from Phoenix,
along with their measurements and metadata, is available in
the "Instrumentation" section of the `Phoenix.Logger` module
documentation.

### An Ecto Example

Like Phoenix, Ecto ships with built-in Telemetry events.
This means that you can gain introspection into your web
and database layers using the same tools.

Here is an example of a Telemetry event executed by Ecto when an Ecto repository starts:

* `[:ecto, :repo, :init]` - dispatched by `Ecto.Repo`

  * Measurement: `%{system_time: native_time}`

  * Metadata: `%{repo: Ecto.Repo, opts: Keyword.t()}`

This means that whenever the `Ecto.Repo` starts, it will emit an event, via `:telemetry`,
with a measurement of the time at start-up.

```elixir
:telemetry.execute([:ecto, :repo, :init], %{system_time: System.system_time()}, %{repo: repo, opts: opts})
```

Additional Telemetry events are executed by Ecto adapters.

One such adapter-specific event is the `[:my_app, :repo, :query]` event.
For instance, if you want to graph query execution time, you can use the `Telemetry.Metrics.summary/2` function to instruct your reporter to calculate statistics of the `[:my_app, :repo, :query]` event, like maximum, mean, percentiles etc.:

```elixir
Telemetry.Metrics.summary("my_app.repo.query.query_time",
  unit: {:native, :millisecond}
)
```

Or you could use the `Telemetry.Metrics.distribution/2` function to define a histogram for another adapter-specific event: `[:my_app, :repo, :query, :queue_time]`, thus visualizing how long queries spend queued:

```elixir
Telemetry.Metrics.distribution("my_app.repo.query.queue_time",
  unit: {:native, :millisecond}
)
```

> You can learn more about Ecto Telemetry in the "Telemetry
Events" section of the
[`Ecto.Repo`](https://hexdocs.pm/ecto/Ecto.Repo.html) module
documentation.

So far we have seen some of the Telemetry events common to
Phoenix applications, along with some examples of their
various measurements and metadata. With all of this data
just waiting to be consumed, let's talk about reporters.

## Reporters

Reporters subscribe to Telemetry events using the common
interface provided by `Telemetry.Metrics`. They then
aggregate the measurements (data) into metrics to provide
meaningful information about your application.

For example, if the following `Telemetry.Metrics.summary/2` call is added to the `metrics/0` function of your Telemetry supervisor:

```elixir
summary("phoenix.endpoint.stop.duration",
  unit: {:native, :millisecond}
)
```

Then the reporter will attach a listener for the `"phoenix.endpoint.stop.duration"` event and will respond to this event by calculating a summary metric with the given event metadata and reporting on that metric to the appropriate source.

### Phoenix.LiveDashboard

For developers interested in real-time visualizations for
their Telemetry metrics, you may be interested in installing
[`LiveDashboard`](https://hexdocs.pm/phoenix_live_dashboard).
LiveDashboard acts as a Telemetry.Metrics reporter to render
your data as beautiful, real-time charts on the dashboard.

### Telemetry.Metrics.ConsoleReporter

`Telemetry.Metrics` ships with a `ConsoleReporter` that can
be used to print events and metrics to the terminal. You can
use this reporter to experiment with the metrics discussed in
this guide.

Uncomment or add the following to this list of children in
your Telemetry supervision tree (usually in
`lib/my_app_web/telemetry.ex`):

```elixir
{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
```

> There are numerous reporters available, for services like
> StatsD, Prometheus, and more. You can find them by
> searching for "telemetry_metrics" on [hex.pm](https://hex.pm/packages?search=telemetry_metrics).

## Phoenix Metrics

Earlier we looked at the "stop" event emitted by
`Plug.Telemetry`, and used it to count the number of HTTP
requests. In reality, it's only somewhat helpful to be
able to see just the total number of requests. What if you
wanted to see the number of requests per route, or per route
_and_ method?

Let's take a look at another event emitted during the HTTP
request lifecycle, this time from `Phoenix.Router`:

* `[:phoenix, :router_dispatch, :stop]` - dispatched by
  Phoenix.Router after successfully dispatching to a matched
  route

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom]}`

Let's start by grouping these events by route. Add the
following (if it does not already exist) to the `metrics/0`
function of your Telemetry supervisor (usually in
`lib/my_app_web/telemetry.ex`):

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    ...metrics...
    summary("phoenix.router_dispatch.stop.duration",
      tags: [:route],
      unit: {:native, :millisecond}
    )
  ]
end
```

Restart your server, and then make requests to a page or two.
In your terminal, you should see the ConsoleReporter print
logs for the Telemetry events it received as a result of
the metrics definitions you provided.

The log line for each request contains the specific route
for that request. This is due to specifying the `:tags`
option for the summary metric, which takes care of our first
requirement; we can use `:tags` to group metrics by route.
Note that reporters will necessarily handle tags differently
depending on the underlying service in use.

Looking more closely at the Router "stop" event, you can see
that the `Plug.Conn` struct representing the request is
present in the metadata, but how do you access the
properties in `conn`?

Fortunately, `Telemetry.Metrics` provides the following
options to help you classify your events:

* `:tags` - A list of metadata keys for grouping;

* `:tag_values` - A function which transforms the metadata
  into the desired shape; Note that this function is called
  for each event, so it's important to keep it fast if the
  rate of events is high.

> Learn about all the available metrics options in the
`Telemetry.Metrics` module documentation.

Let's find out how to extract more tags from events that
include a `conn` in their metadata.

### Extracting tag values from Plug.Conn

Let's add another metric for the route event, this time to
group by route and method:

```elixir
summary("phoenix.router_dispatch.stop.duration",
  tags: [:method, :route],
  tag_values: &get_and_put_http_method/1,
  unit: {:native, :millisecond}
)
```

We've introduced the `:tag_values` option here, because we
need to perform a transformation on the event metadata in
order to get to the values we need.

Add the following private function to your Telemetry module
to lift the `:method` value from the `Plug.Conn` struct:

```elixir
# lib/my_app_web/telemetry.ex
defp get_and_put_http_method(%{conn: %{method: method}} = metadata) do
  Map.put(metadata, :method, method)
end
```

Restart your server and make some more requests. You should
begin to see logs with tags for both the HTTP method and the
route.

Note the `:tags` and `:tag_values` options can be applied to
all `Telemetry.Metrics` types.

### Renaming value labels using tag values

Sometimes when displaying a metric, the value label may need to be transformed
to improve readability. Take for example the following metric that displays the
duration of the each LiveView's `mount/3` callback by `connected?` status.

```elixir
summary("phoenix.live_view.mount.stop.duration",
  unit: {:native, :millisecond},
  tags: [:view, :connected?],
  tag_values: &live_view_metric_tag_values/1
)
```

The following function lifts `metadata.socket.view` and
`metadata.socket.connected?` to be top-level keys on `metadata`, as we did in
the previous example.

```elixir
# lib/my_app_web/telemetry.ex
defp live_view_metric_tag_values(metadata) do
  metadata
  |> Map.put(:view, metadata.socket.view)
  |> Map.put(:connected?, Phoenix.LiveView.connected?(metadata.socket))
end
```

However, when rendering these metrics in LiveDashboard, the value label is
output as `"Elixir.Phoenix.LiveDashboard.MetricsLive true"`.

To make the value label easier to read, we can update our private function to
generate more user friendly names. We'll run the value of the `:view` through
`inspect/1` to remove the `Elixir.` prefix and call another private function to
convert the `connected?` boolean into human readable text.

```elixir
# lib/my_app_web/telemetry.ex
defp live_view_metric_tag_values(metadata) do
  metadata
  |> Map.put(:view, inspect(metadata.socket.view))
  |> Map.put(:connected?, get_connection_status(Phoenix.LiveView.connected?(metadata.socket)))
end

defp get_connection_status(true), do: "Connected"
defp get_connection_status(false), do: "Disconnected"
```

Now the value label will be rendered like `"Phoenix.LiveDashboard.MetricsLive
Connected"`.

Hopefully, this gives you some inspiration on how to use the `:tag_values`
option. Just remember to keep this function fast since it is called on every
event.

## Periodic measurements

You might want to periodically measure key-value pairs within
your application. Fortunately the
[`:telemetry_poller`](https://hexdocs.pm/telemetry_poller)
package provides a mechanism for custom measurements,
which is useful for retrieving process information or for
performing custom measurements periodically.

Add the following to the list in your Telemetry supervisor's
`periodic_measurements/0` function, which is a private
function that returns a list of measurements to take on a
specified interval.

```elixir
# lib/my_app_web/telemetry.ex
defp periodic_measurements do
  [
    {MyApp, :measure_users, []},
    {:process_info,
      event: [:my_app, :my_server],
      name: MyApp.MyServer,
      keys: [:message_queue_len, :memory]}
  ]
end
```

where `MyApp.measure_users/0` could be written like this:

```elixir
# lib/my_app.ex
defmodule MyApp do
  def measure_users do
    :telemetry.execute([:my_app, :users], %{total: MyApp.users_count()}, %{})
  end
end
```

Now with measurements in place, you can define the metrics for the
events above:

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    ...metrics...
    # MyApp Metrics
    last_value("my_app.users.total"),
    last_value("my_app.my_server.memory", unit: :byte),
    last_value("my_app.my_server.message_queue_len")
    summary("my_app.my_server.call.stop.duration"),
    counter("my_app.my_server.call.exception")
  ]
end
```

> You will implement MyApp.MyServer in the
[Custom Events](#custom-events) section.

## Libraries using Telemetry

Telemetry is quickly becoming the de-facto standard for
package instrumentation in Elixir. Here is a list of
libraries currently emitting `:telemetry` events.

Library authors are actively encouraged to send a PR adding
their own (in alphabetical order, please):

* [Absinthe](https://hexdocs.pm/absinthe) - [Events](https://hexdocs.pm/absinthe/telemetry.html)
* [Ash Framework](https://hexdocs.pm/ash) - [Events](https://hexdocs.pm/ash/monitoring.html)
* [Broadway](https://hexdocs.pm/broadway) - [Events](https://hexdocs.pm/broadway/Broadway.html#module-telemetry)
* [Ecto](https://hexdocs.pm/ecto) - [Events](https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events)
* [Oban](https://hexdocs.pm/oban) - [Events](https://hexdocs.pm/oban/Oban.Telemetry.html)
* [Phoenix](https://hexdocs.pm/phoenix) - [Events](https://hexdocs.pm/phoenix/Phoenix.Logger.html#module-instrumentation)
* [Plug](https://hexdocs.pm/plug) - [Events](https://hexdocs.pm/plug/Plug.Telemetry.html)
* [Tesla](https://hexdocs.pm/tesla) - [Events](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html)

## Custom Events

If you need custom metrics and instrumentation in your
application, you can utilize the `:telemetry` package
(<https://hexdocs.pm/telemetry>) just like your favorite
frameworks and libraries.

Here is an example of a simple GenServer that emits telemetry
events. Create this file in your app at
`lib/my_app/my_server.ex`:

```elixir
# lib/my_app/my_server.ex
defmodule MyApp.MyServer do
  @moduledoc """
  An example GenServer that runs arbitrary functions and emits telemetry events when called.
  """
  use GenServer

  # A common prefix for :telemetry events
  @prefix [:my_app, :my_server, :call]

  def start_link(fun) do
    GenServer.start_link(__MODULE__, fun, name: __MODULE__)
  end

  @doc """
  Runs the function contained within this server.

  ## Events

  The following events may be emitted:

    * `[:my_app, :my_server, :call, :start]` - Dispatched
      immediately before invoking the function. This event
      is always emitted.

      * Measurement: `%{system_time: system_time}`

      * Metadata: `%{}`

    * `[:my_app, :my_server, :call, :stop]` - Dispatched
      immediately after successfully invoking the function.

      * Measurement: `%{duration: native_time}`

      * Metadata: `%{}`

    * `[:my_app, :my_server, :call, :exception]` - Dispatched
      immediately after invoking the function, in the event
      the function throws or raises.

      * Measurement: `%{duration: native_time}`

      * Metadata: `%{kind: kind, reason: reason, stacktrace: stacktrace}`
  """
  def call!, do: GenServer.call(__MODULE__, :called)

  @impl true
  def init(fun) when is_function(fun, 0), do: {:ok, fun}

  @impl true
  def handle_call(:called, _from, fun) do
    # Wrap the function invocation in a "span"
    result = telemetry_span(fun)

    {:reply, result, fun}
  end

  # Emits telemetry events related to invoking the function
  defp telemetry_span(fun) do
    start_time = emit_start()

    try do
      fun.()
    catch
      kind, reason ->
        stacktrace = System.stacktrace()
        duration = System.monotonic_time() - start_time
        emit_exception(duration, kind, reason, stacktrace)
        :erlang.raise(kind, reason, stacktrace)
    else
      result ->
        duration = System.monotonic_time() - start_time
        emit_stop(duration)
        result
    end
  end

  defp emit_start do
    start_time_mono = System.monotonic_time()

    :telemetry.execute(
      @prefix ++ [:start],
      %{system_time: System.system_time()},
      %{}
    )

    start_time_mono
  end

  defp emit_stop(duration) do
    :telemetry.execute(
      @prefix ++ [:stop],
      %{duration: duration},
      %{}
    )
  end

  defp emit_exception(duration, kind, reason, stacktrace) do
    :telemetry.execute(
      @prefix ++ [:exception],
      %{duration: duration},
      %{
        kind: kind,
        reason: reason,
        stacktrace: stacktrace
      }
    )
  end
end
```

and add it to your application's supervisor tree (usually in
`lib/my_app/application.ex`), giving it a function to invoke
when called:

```elixir
# lib/my_app/application.ex
children = [
  # Start a server that greets the world
  {MyApp.MyServer, fn -> "Hello, world!" end},
]
```

Now start an IEx session and call the server:

```elixir
iex> MyApp.MyServer.call!
```

and you should see something like the following output:

```text
[Telemetry.Metrics.ConsoleReporter] Got new event!
Event name: my_app.my_server.call.stop
All measurements: %{duration: 4000}
All metadata: %{}

Metric measurement: #Function<2.111777250/1 in Telemetry.Metrics.maybe_convert_measurement/2> (summary)
With value: 0.004 millisecond
Tag values: %{}

"Hello, world!"
```
