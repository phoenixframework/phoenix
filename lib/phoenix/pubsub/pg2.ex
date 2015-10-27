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

  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts], name: supervisor_name)
  end

  @doc false
  def init([server, opts]) do
    pool_size = Keyword.fetch!(opts, :pool_size)
    IO.puts ">> Starting PG2 with a pool size of #{pool_size}"
    local = Module.concat(server, Local)
    gc = Module.concat(server, GC)

    # Define a dispatch table so we don't have to go through
    # a bottleneck to get the instruction to perform.
    :ets.new(server, [:set, :named_table, read_concurrency: true])
    ^local = :ets.new(local, [:bag, :named_table, :public, read_concurrency: true])
    true = :ets.insert(server, {:broadcast, Phoenix.PubSub.PG2Server, [server, local, pool_size]})
    true = :ets.insert(server, {:subscribe, Phoenix.PubSub.Local, [local, pool_size]})
    true = :ets.insert(server, {:unsubscribe, Phoenix.PubSub.Local, [local, pool_size]})

    locals = for shard <- 0..(pool_size - 1) do
      local_shard_name = Module.concat(["#{local}#{shard}"])
      gc_shard_name = Module.concat(["#{gc}#{shard}"])
      true = :ets.insert(local, {shard, local_shard_name})
      worker(Phoenix.PubSub.Local, [local_shard_name, gc_shard_name], id: local_shard_name)
    end

    gcs = for shard <- 0..(pool_size - 1) do
      gc_shard_name = Module.concat(["#{gc}#{shard}"])
      local_shard_name = Module.concat(["#{local}#{shard}"])
      worker(Phoenix.PubSub.GC, [gc_shard_name, local_shard_name], id: gc_shard_name)
    end

    children = locals ++ gcs ++ [
      worker(Phoenix.PubSub.PG2Server, [server, local]),
    ]

    supervise children, strategy: :rest_for_one
  end
end
