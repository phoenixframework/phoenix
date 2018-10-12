defmodule Phoenix.Socket.PoolSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def start_child(endpoint, name, key, args) do
    case endpoint.config({:socket, name}) do
      ets when not is_nil(ets) ->
        partitions = :ets.lookup_element(ets, :partitions, 2)
        sup = :ets.lookup_element(ets, :erlang.phash2(key, partitions), 2)
        Supervisor.start_child(sup, args)

      nil ->
        raise ArgumentError, """
        no socket supervision tree found for #{inspect(name)}.

        Ensure your #{inspect(endpoint)} contains a socket mount, for example:

            socket "/socket", #{inspect(name)},
              websocket: true,
              longpoll: true
        """
    end
  end

  @doc false
  def start_pooled(worker, ref, i) do
    case Supervisor.start_link([worker], strategy: :simple_one_for_one) do
      {:ok, pid} ->
        :ets.insert(ref, {i, pid})
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def init({endpoint, name, partitions, worker}) do
    import Supervisor.Spec

    ref = :ets.new(name, [:public, read_concurrency: true])
    :ets.insert(ref, {:partitions, partitions})
    Phoenix.Config.permanent(endpoint, {:socket, name}, ref)

    children =
      for i <- 0..(partitions - 1) do
        supervisor(__MODULE__, [worker, ref, i], id: i, function: :start_pooled)
      end

    supervise(children, strategy: :one_for_one)
  end
end
