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
a closer look what makes up a telemetry event.

## Telemetry Events

Many Elixir libraries (including Phoenix) are already using
the `:telemetry` package (http://hexdocs.pm/telemetry) as a
way to give users more insight into the behavior of their
applications, by emitting events at key moments in the
application lifecycle.

### A Phoenix Example

Here is an example of a telemetry event from
`Phoenix.Endpoint`:

* `[:phoenix, :endpoint, :stop]` - dispatched by
  `Plug.Telemetry` in your endpoint whenever the response is
  sent

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t}`

This means that after each request, Phoenix, via telemetry,
will emit a "stop" event, with a measurement of how long it
took to get the response:

```elixir
:telemetry.execute([:phoenix, :endpoint, :stop], %{duration: duration}, %{conn: conn})
```

## Telemetry.Metrics

> Metrics are aggregations of Telemetry events with a specific name,
providing a view of the system's behaviour over time. -- _`Telemetry.Metrics`_

Using `Telemetry.Metrics`, you can define a counter metric,
which counts how many HTTP requests were completed:

```elixir
Telemetry.Metrics.counter("phoenix.endpoint.stop.duration")
```

or you could use a distribution metric to see how many
requests were completed in particular time buckets:

```elixir
Telemetry.Metrics.distribution("phoenix.endpoint.stop.duration", buckets: [100, 200, 300])
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
the "Instrumentation" section of `Phoenix.Endpoint` module
documentation.

### An Ecto Example

Like Phoenix, Ecto ships with built-in telemetry events.
This means that you can gain introspection into your web
and database layers using the same tools.

For instance, you might want to graph query execution time:

```elixir
Telemetry.Metrics.summary("my_app.repo.query.query_time",
  unit: {:native, :millisecond}
)
```

or view how long queries spend queued:

```elixir
Telemetry.Metrics.distribution("my_app.repo.query.queue_time",
  unit: {:native, :millisecond},
  buckets: [10, 50, 100]
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

Reporters can subscribe to the Telemetry events you define,
and use the common interface provided by `Telemetry.Metrics`,
along with the measurements and metadata emitted in Telemetry
events, to provide information meaningful to your
application.

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

Add the following to this list of children in your Telemetry
supervision tree (usually in `lib/my_app_web/telemetry.ex`):

```elixir
{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
```

> There are numerous reporters available, for services like
> StatsD, Prometheus, and more. You can find them by
> searching for "telemetry_metrics" on https://hex.pm.

## Phoenix Metrics

Earlier we looked at the stop event emitted by
`Phoenix.Endpoint`, and used it to count the number of HTTP
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

Looking more closely at the Router stop event, you can see
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
  unit: {:native, :millisecond}
  tag_values: &get_and_put_http_method/1
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

## VM metrics and periodic measurements

You might want to periodically measure key values within
your application.

The `:telemetry_poller` package
(http://hexdocs.pm/telemetry_poller) exposes numerous
VM-related metrics and also provides custom periodic
measurements. You can add `:telemetry_poller` as a
dependency:

```elixir
  {:telemetry_poller, "~> 0.4"}
```

### Built-in measurements

By simply adding `:telemetry_poller` as a dependency, two
events become available:

* `[:vm, :memory]` - contains the total memory, as well as
  the memory used for binaries, processes, etc. See
  `erlang:memory/0` for all keys;

* `[:vm, :total_run_queue_lengths]` - returns the run queue
  lengths for CPU and IO schedulers. It contains the
  `total`, `cpu` and `io` measurements;

You can add VM metrics by modifying your `telemetry.ex` file.

Update your `metrics/0` function to include some VM metrics:

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    ...metrics...
    # VM Metrics
    last_value("vm.memory.total", unit: :byte),
    summary("vm.total_run_queue_lengths.total"),
    summary("vm.total_run_queue_lengths.cpu"),
    summary("vm.total_run_queue_lengths.io")
  ]
end
```

If you want to change the frequency of those measurements, you can set the
following configuration in your config file:

    config :telemetry_poller, :default, period: 5_000 # the default

Or disable it completely with:

    config :telemetry_poller, :default, false

### Custom periodic measurements

The `:telemetry_poller` package also allows you to run your
own poller, which is useful to retrieve process information
or perform custom measurements periodically.

Add `:telemetry_poller` to your telemetry supervision tree:

```elixir
# lib/my_app_web/telemetry.ex
children = [
  # Start the telemetry poller
  {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
  ...reporters...
]

Supervisor.init(children, strategy: :one_for_one)
```

Next you'll need to define `periodic_measurements/0`, which
is a private function that returns a list of measurements to
take on the specified interval.

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
    counter("my_app.my_server.call.exception)
  ]
end
```

> You will implement MyApp.MyServer in the
[Custom Events](#custom-events) section.

## Libraries using Telemetry

Telemetry is quickly becoming the de-facto standard for
instrumenting events in Elixir. Here is a list of libraries
currently emitting `:telemetry` events.

Library authors are actively encouraged to send a PR adding
their own (in alphabetical order, please):

* [Absinthe](https://hexdocs.pm/absinthe) - Coming Soon!
* [Broadway](https://hexdocs.pm/broadway) - [Events](https://hexdocs.pm/broadway/Broadway.html#module-telemetry)
* [Ecto](https://hexdocs.pm/ecto) - [Events](https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events)
* [Oban](https://hexdocs.pm/oban) - [Events](https://hexdocs.pm/oban/Oban.Telemetry.html)
* [Phoenix](https://hexdocs.pm/phoenix) - [Events](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-instrumentation)
* [Plug](https://hexdocs.pm/plug) - [Events](https://hexdocs.pm/plug/Plug.Telemetry.html)
* [Tesla](https://hexdocs.pm/tesla) - [Events](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html)

## Custom Events

If you need custom metrics and instrumentation in your
application, you can utilize the `:telemetry` package
(https://hexdocs.pm/telemetry) just like your favorite
frameworks and libraries.

Here is an example of a simple GenServer that emits telemetry
events. Create this file in your app at `lib/my_app/my_server.ex`:

```elixir
defmodule MyApp.MyServer do
  @moduledoc """
  An example GenServer that emits telemetry events when called.
  """
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @doc """
  Changes the function that this server will call.

  ## Example

      iex> MyApp.MyServer.become fn -> "Hello, world!" end
      iex> :ok

      iex> MyApp.MyServer.call!
      "Hello, world!"
  """
  def become(fun) when is_function(fun, 0) do
    GenServer.call(__MODULE__, {:become, fun})
  end

  @doc """
  Calls the function contained within this server.
  """
  def call!, do: GenServer.call(__MODULE__, :called)

  @impl true
  def init(opts) do
    fun = if is_function(opts[:fun]), do: opts[:fun], else: fn -> nil end
    {:ok, %{fun: fun}}
  end

  @impl true
  def handle_call({:become, fun}, _from, state) when is_function(fun) do
    {:reply, :ok, %{state | fun: fun}}
  end

  def handle_call(:called, _from, state) do
    start_time = emit_start()

    result =
      try do
        state.fun.()
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

    {:reply, result, state}
  end

  defp emit_start do
    start_time_mono = System.monotonic_time()

    :telemetry.execute(
      [:my_app, :my_server, :call, :start],
      %{system_time: System.system_time()},
      %{}
    )

    start_time_mono
  end

  defp emit_stop(duration) do
    :telemetry.execute(
      [:my_app, :my_server, :call, :stop],
      %{duration: duration},
      %{}
    )
  end

  defp emit_exception(duration, kind, reason, stacktrace) do
    :telemetry.execute(
      [:my_app, :my_server, :call, :exception],
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
`lib/my_app/application.ex`):

```elixir
# lib/my_app/application.ex
children = [
  # Start the example server
  MyApp.MyServer,
]
```
