defmodule Phoenix.Socket.PoolSupervisor do
  @moduledoc false
  use Supervisor

  def start_link({name, _partitions, _worker} = triplet) do
    Supervisor.start_link(__MODULE__, triplet, name: name)
  end

  def start_child(name, key, args) do
    partitions = :ets.lookup_element(name, :partitions, 2)
    sup = :ets.lookup_element(name, :erlang.phash2(key, partitions), 2)
    Supervisor.start_child(sup, args)
  end

  @doc false
  def init({name, partitions, worker}) do
    import Supervisor.Spec

    ref = :ets.new(name, [:named_table, :public, read_concurrency: true])
    :ets.insert(ref, {:partitions, partitions})

    children =
      for i <- 0..(partitions - 1) do
        name = :"#{name}#{i}"
        :ets.insert(ref, {i, name})
        supervisor_opts = [strategy: :simple_one_for_one, name: name]
        supervisor(Supervisor, [[worker], supervisor_opts], id: name)
      end

    supervise(children, strategy: :one_for_one)
  end
end
