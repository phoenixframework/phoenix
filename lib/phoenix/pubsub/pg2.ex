defmodule Phoenix.PubSub.PG2 do
  use Supervisor

  @moduledoc """
  Phoenix PubSub adapter based on PG2.

  To use it as your PubSub adapter, simply add it to your Endpoint's config:

      config :my_app, MyApp.Endpoint,
        pubsub: [adapter: Phoenix.PubSub.PG2]

  ## Options

    * `:name` - The name to register the PubSub processes, ie: `MyApp.PubSub`

  """

  def start_link(name, _opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, name, name: supervisor_name)
  end

  @doc false
  def init(server_name) do
    local_name = Module.concat(server_name, Local)
    gc_name = Module.concat(server_name, GC)

    # Define a dispatch table so we don't have to go through
    # a bottleneck to get the instruction to perform.
    :ets.new(server_name, [:set, :named_table, read_concurrency: true])
    true = :ets.insert(server_name, {:broadcast, Phoenix.PubSub.PG2Server, [server_name, local_name]})
    true = :ets.insert(server_name, {:subscribe, Phoenix.PubSub.Local, [local_name]})
    true = :ets.insert(server_name, {:unsubscribe, Phoenix.PubSub.Local, [local_name]})

    children = [
      worker(Phoenix.PubSub.Local, [local_name, gc_name]),
      worker(Phoenix.PubSub.GC, [gc_name, local_name]),
      worker(Phoenix.PubSub.PG2Server, [server_name, local_name]),
    ]

    supervise children, strategy: :rest_for_one
  end
end
