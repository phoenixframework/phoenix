# Telemetry

> `te·lem·e·try` - the process of recording and transmitting
the readings of an instrument.

Many Elixir libraries (including Phoenix) are already using
the `:telemetry` package (http://hexdocs.pm/telemetry) as a
way to give users more insight into the behavior of their
applications, by emitting events at key moments in the
application lifecycle.

This guide provides more specific information about some
of the features detailed in the Phoenix
[LiveDashboard Metrics](https://hexdocs.pm/phoenix_live_dashboard/metrics.html)
guide. While some parts of this guide are geared specifically
towards users of the dashboard, it may also serve as a
general introduction to reporting metrics from any
Elixir/Phoenix application.

### A Phoenix Example

Here is an example of a telemetry event from
`Phoenix.Endpoint`:

* `[:phoenix, :endpoint, :stop]` - dispatched by
  `Plug.Telemetry` in your endpoint whenever the response is
  sent

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t}`

To get a better understanding of what this means, search
for `Plug.Telemetry` in your application's Endpoint (usually
in `lib/my_app_web/endpoint.ex`), and you
should see something like this:

```elixir
plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
```

> Note: For older Phoenix apps, this is Step #1 for
integrating Telemetry Metrics into Phoenix. Be sure
`Plug.Telemetry` is present in your Endpoint, otherwise you
will not receive any of the `"phoenix.endpoint.*"` events
that will be discussed throughout this guide.

After each request, `Plug.Telemetry` will emit the stop event,
with a measurement of how long it took to get the response:

```elixir
:telemetry.execute([:phoenix, :endpoint, :stop], %{duration: duration}, %{conn: conn})
```

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
summary("my_app.repo.query.query_time", unit: {:native, :millisecond})
```

or view how long queries spend queued:

```elixir
distribution("my_app.repo.query.queue_time",
  unit: {:native, :millisecond},
  buckets: [10, 50, 100]
)
```

> You can learn more about Ecto Telemetry in the "Telemetry
Events" section of the
[`Ecto.Repo`](https://hexdocs.pm/ecto/Ecto.Repo.html) module
documentation, as well as in the [Ecto Metrics](#ecto-metrics)
section later in this guide.

## LiveMetrics Dashboard

`Telemetry.Metrics` relies on reporters to subscribe to
events, and LiveDashboard is simply one such reporter: it
attaches to the `:telemetry` events matching the metrics you
specify, and renders the aggregate data as beautiful,
real-time charts on the dashboard.

However there are numerous reporters available within the
Elixir ecosystem for tools like StatsD, Prometheus, etc.
Using `Telemetry.Metrics` means you can write your metrics
definitions once, and by utilizing different reporters, they
can be sent to multiple destinations simultaneously.

## Phoenix Metrics

As mentioned previously, the Phoenix framework comes with
numerous built-in telemetry events that you can visualize
with LiveDashboard.

You can start rendering simple charts by defining a list of
metrics in the `metrics/0` function of your Telemetry
supervisor (usually in `lib/my_app_web/telemetry.ex`):

```elixir
# lib/my_app_web/telemetry.ex
defp metrics do
  [
    # Phoenix Metrics
    counter("phoenix.endpoint.stop.duration")
    summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond})
  ]
end
```

Restart your server. When LiveDashboard reconnects, you
should see two new charts rendered on the dashboard:

* A `Doughnut` chart with a single value, increasing by
   1 for each completed request;

* A `Line` chart for a timeseries of the duration of each
  completed request;

In reality, it's only _somewhat_ helpful to be able to see
the total number of requests. What if you wanted to see the
number of requests per page, or even per Controller action?

To visualize, let's look at two different examples of
grouping HTTP requests: one will group events by HTTP method
and request path, resulting in x-axis labels such as
`"GET /"`, while the other will group by Phoenix Controller
and action, resulting in labels such as
`"IndexController:show"`.

Looking at the Endpoint stop event, you can see that the
`Plug.Conn` struct representing the request is present in
the metadata, but how do you access the properties in
`conn`?

Fortunately, `Telemetry.Metrics` comes with options to help
you with this:

* `:tags` - A list of metadata keys for grouping;

* `:tag_values` - A function which transforms the metadata
  into the desired shape; Note that this function is called
  for each event, so it's important to keep it fast if the
  rate of events is high.

> Learn about all the available metrics options in the
`Telemetry.Metrics` module documentation.

Let's find out how to tag events that include a `conn` in
their metadata.

### Tagging Endpoint events by method and request path

Let's take another look at one of current metrics, the
request `counter`:

```elixir
counter("phoenix.endpoint.stop.duration")
```

You are going to modify this metric to add a new chart that
will group data by HTTP method and request path. It will be
rendered on the LiveDashboard as a segmented `Doughnut`
chart, with data labels such as `"GET /home"` and
`"POST /users/new"`.

To do so, you need to provide the `:tags` option to the
metric, which LiveDashboard will use to extract values from
the metadata, in order to generate the desired labels.

You can add a new `counter` to your list of metrics:

```elixir
# lib/my_app_web/telemetry.ex
defp metrics do
  [
    ...metrics...
    counter("phoenix.endpoint.stop.duration",
      tags: [:method, :request_path],
      tag_values: &tag_method_and_request_path/1
    )
  ]
end
```

Then you also need to define a function for `:tag_values` that
can extract the desired metadata from `Plug.Conn`.

Add this private function to your Telemetry module:

```elixir
# lib/my_app_web/telemetry.ex
defp tag_method_and_request_path(metadata) do
  %{conn: %Plug.Conn{} = conn} = metadata

  Map.merge(metadata, Map.take(conn, [:method, :request_path]))
end
```

Restart your server and you should see the new chart appear
on the dashboard. Visit some other pages on your site, and
you should begin to see new sections appear on your counter
Doughnut chart.

The `:tags` and `:tag_values` options apply to all
`Telemetry.Metrics` types, so they will work with all
LiveDashboard chart types, too.

### Tagging Endpoint events by controller and action

Now that you've seen how to group by metadata, and how to
transform metadata into any desired shape, you can probably
guess where we are going next. Grouping by Controller action
isn't any different than grouping by method and path -
you can utilize built-in Phoenix functions within your
`:tag_values` callback to generate the relevant values.

Now add _another_ counter, this time grouping by Controller
action:

```elixir
# lib/my_app_web/telemetry.ex
defp metrics do
  [
    ...metrics...
    counter("phoenix.endpoint.stop.duration",
      tags: [:label],
      tag_values: &tag_controller_action_label/1
    )
  ]
end
```

Notice we are recommending a single tag,
`:label`, instead of keeping `:controller` and `:action`
separate. In some situations, such as rendering a LiveView,
you may not have two separate values, so it's better to
treat them as a single label.

Add the private `conn_to_controller_action_label/2` function to
your Telemetry module:

```elixir
# lib/my_app_web/telemetry.ex
import Phoenix.Controller, only: [controller_module: 1, action_name: 1]

defp tag_controller_action_label(metadata) do
  %{conn: %Plug.Conn{} = conn} = metadata

  label =
    try do
      # TODO: identify a LiveView
      "#{controller_module(conn)}:#{action_name(conn)}"
    rescue
      _ ->
        "LiveView, probably"
    end

  Map.put(metadata, :label, label)
end
```


## Ecto Metrics

_TODO_

```elixir
defp metrics do
  [
    ...metrics...
    # Ecto Metrics
    summary("my_app.repo.query.total_time", unit: {:native, :millisecond}),
    summary("my_app.repo.query.decode_time", unit: {:native, :millisecond}),
    summary("my_app.repo.query.query_time", unit: {:native, :millisecond}),
    summary("my_app.repo.query.queue_time", unit: {:native, :millisecond}),
  ]
end
```

## VM Metrics

`Telemetry.Metrics` doesn't have a special treatment for the
VM metrics - they need to be based on the events like all
other metrics.

The `:telemetry_poller` package
(http://hexdocs.pm/telemetry_poller) exposes a bunch of
VM-related metrics and also provides custom periodic
measurements. You can add telemetry poller as a dependency:

```elixir
  {:telemetry_poller, "~> 0.4"}
```

### Built-in Measurements

By simply adding `:telemetry_poller` as a dependency, two
events will become available:

* `[:vm, :memory]` - contains the total memory, as well as
  the memory used for binaries, processes, etc. See
  `erlang:memory/0` for all keys;

* `[:vm, :total_run_queue_lengths]` - returns the run queue
  lengths for CPU and IO schedulers. It contains the
  `total`, `cpu` and `io` measurements;

You can add VM metrics to LiveDashboard by modifying your
`telemetry.ex` file.

Update your `metrics/0` function to include some VM metrics:

```elixir
# lib/my_app_web/telemetry.ex
defp metrics do
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

### Custom Periodic Measurements

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
      event: [:my_app, :worker],
      name: MyApp.Worker,
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
defp metrics do
  [
    ...metrics...
    # MyApp Metrics
    last_value("my_app.users.total"),
    last_value("my_app.worker.memory", unit: :byte),
    last_value("my_app.worker.message_queue_len")
  ]
end
```

> We'll implement MyApp.Worker in the
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
* [Tesla](https://hexdocs.pm/tesla) - [Events](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html)

## Custom Events

If you need custom metrics and instrumentation in your
application, you can utilize the `:telemetry` package
(https://hexdocs.pm/telemetry) just like your favorite
frameworks and libraries.

_TODO_
