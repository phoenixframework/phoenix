defmodule Phoenix.Socket.PoolSupervisor do
  @moduledoc false
  use Supervisor

  # TODO: Use PartitionSupervisor once we require Elixir v1.14
  def start_link({endpoint, name, partitions}) do
    Supervisor.start_link(
      __MODULE__,
      {endpoint, name, partitions},
      name: Module.concat(endpoint, name)
    )
  end

  def start_child(endpoint, name, key, spec) do
    case endpoint.config({:socket, name}) do
      ets when not is_nil(ets) ->
        partitions = :ets.lookup_element(ets, :partitions, 2)
        sup = :ets.lookup_element(ets, :erlang.phash2(key, partitions), 2)
        DynamicSupervisor.start_child(sup, spec)

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
  def start_pooled(ref, i) do
    case DynamicSupervisor.start_link(strategy: :one_for_one) do
      {:ok, pid} ->
        :ets.insert(ref, {i, pid})
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def init({endpoint, name, partitions}) do
    ref = :ets.new(name, [:public, read_concurrency: true])
    :ets.insert(ref, {:partitions, partitions})
    Phoenix.Config.permanent(endpoint, {:socket, name}, ref)

    children =
      for i <- 0..(partitions - 1) do
        %{
          id: i,
          start: {__MODULE__, :start_pooled, [ref, i]},
          type: :supervisor,
          shutdown: :infinity
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
