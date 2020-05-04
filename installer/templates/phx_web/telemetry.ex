defmodule <%= web_namespace %>.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
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
      ),<%= if ecto do %>

      # Database Metrics
      summary("<%= app_name %>.repo.query.total_time", unit: {:native, :millisecond}),
      summary("<%= app_name %>.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("<%= app_name %>.repo.query.query_time", unit: {:native, :millisecond}),
      summary("<%= app_name %>.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("<%= app_name %>.repo.query.idle_time", unit: {:native, :millisecond}),<% end %>

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
      # {<%= web_namespace %>, :count_users, []}
    ]
  end
end
