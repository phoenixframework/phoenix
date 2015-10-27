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
  @pool_size Application.get_env(:phoenix, :pubsub_shard_size, 50)

  def start_link(name, _opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, name, name: supervisor_name)
  end

  @doc false
  def init(server_name) do
    local_name = Module.concat(server_name, Local)

    # Define a dispatch table so we don't have to go through
    # a bottleneck to get the instruction to perform.
    :ets.new(server_name, [:set, :named_table, read_concurrency: true])
    true = :ets.insert(server_name, {:broadcast, Phoenix.PubSub.PG2Server, [server_name, local_name, @pool_size]})
    true = :ets.insert(server_name, {:subscribe, Phoenix.PubSub.Local, [local_name, @pool_size]})
    true = :ets.insert(server_name, {:unsubscribe, Phoenix.PubSub.Local, [local_name, @pool_size]})

    locals = for i <- 1..@pool_size do
      name = Module.concat(["#{local_name}#{i}"])
      worker(Phoenix.PubSub.Local, [name], id: name)
    end

    children = locals ++ [
      worker(Phoenix.PubSub.PG2Server, [server_name, local_name]),
    ]

    supervise children, strategy: :rest_for_one
  end
end
