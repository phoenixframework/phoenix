defmodule Phoenix.PubSub.LocalSupervisor do
  use Supervisor
  alias Phoenix.PubSub.Local

  @moduledoc """
  Local PubSub server supervisor.

  Used by PubSub adapters to handle "local" subscriptions.
  Defines an ets dispatch table for routing subcription
  requests. Extendable by PubSub adapters by providing
  a list of `dispatch_rules` to extend the dispatch table.

  See `Phoenix.PubSub.PG2` for example usage.
  """

  def start_link(server, pool_size, dispatch_rules) do
    Supervisor.start_link(__MODULE__, [server, pool_size, dispatch_rules])
  end

  @doc false
  def init([server, pool_size, dispatch_rules]) do
    # Define a dispatch table so we don't have to go through
    # a bottleneck to get the instruction to perform.
    ^server = :ets.new(server, [:set, :named_table, read_concurrency: true])
    true = :ets.insert(server, {:subscribe, Phoenix.PubSub.Local, [server, pool_size]})
    true = :ets.insert(server, {:unsubscribe, Phoenix.PubSub.Local, [server, pool_size]})
    true = :ets.insert(server, dispatch_rules)

    children = for shard <- 0..(pool_size - 1) do
      local_shard_name = Local.local_name(server, shard)
      gc_shard_name    = Local.gc_name(server, shard)
      true = :ets.insert(server, {shard, {local_shard_name, gc_shard_name}})

      shard_children = [
        worker(Phoenix.PubSub.GC, [gc_shard_name, local_shard_name]),
        worker(Phoenix.PubSub.Local, [local_shard_name, gc_shard_name]),
      ]

      supervisor(Supervisor, [shard_children, [strategy: :one_for_all]], id: shard)
    end

    supervise children, strategy: :one_for_one
  end
end
