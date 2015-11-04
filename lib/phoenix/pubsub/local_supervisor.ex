defmodule Phoenix.PubSub.LocalSupervisor do
  use Supervisor

  @moduledoc false

  def start_link(local, gc, pool_size) do
    Supervisor.start_link(__MODULE__, [local, gc, pool_size])
  end

  @doc false
  def init([local, gc, pool_size]) do
    ^local = :ets.new(local, [:set, :named_table, :public, read_concurrency: true])

    children = for shard <- 0..(pool_size - 1) do
      local_shard_name = Module.concat(["#{local}#{shard}"])
      gc_shard_name    = Module.concat(["#{gc}#{shard}"])
      true = :ets.insert(local, {shard, local_shard_name})

      shard_children = [
        worker(Phoenix.PubSub.GC, [gc_shard_name, local_shard_name], id: gc_shard_name),
        worker(Phoenix.PubSub.Local, [local_shard_name, gc_shard_name], id: local_shard_name)
      ]

      supervisor(Supervisor, [shard_children, [strategy: :one_for_all]])
    end

    supervise children, strategy: :one_for_one
  end
end
