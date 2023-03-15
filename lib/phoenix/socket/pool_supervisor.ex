defmodule Phoenix.Socket.PoolSupervisor do
  @moduledoc false
  use Supervisor

  def start_link({endpoint, name, partitions}) do
    Supervisor.start_link(
      __MODULE__,
      {endpoint, name, partitions},
      name: Module.concat(endpoint, name)
    )
  end

  def start_child(socket, key, spec) do
    %{endpoint: endpoint, handler: name} = socket

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

  def start_pooled(ref, i) do
    case DynamicSupervisor.start_link(strategy: :one_for_one) do
      {:ok, pid} ->
        :ets.insert(ref, {i, pid})
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def init({endpoint, name, partitions}) do
    # TODO: Use persisent term on Elixir v1.12+
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

defmodule Phoenix.Socket.PoolDrainer do
  @moduledoc false
  use GenServer
  require Logger

  def child_spec({_endpoint, name, shutdown, _interval} = tuple) do
    # The process should terminate within shutdown but,
    # in case it doesn't, we will be killed if we exceed
    # double of that
    %{
      id: {:terminator, name},
      start: {__MODULE__, :start_link, [tuple]},
      shutdown: shutdown * 2
    }
  end

  def start_link(tuple) do
    GenServer.start_link(__MODULE__, tuple)
  end

  @impl true
  def init(tuple) do
    Process.flag(:trap_exit, true)
    {:ok, tuple}
  end

  @impl true
  def terminate(_reason, {endpoint, name, shutdown, interval}) do
    ets = endpoint.config({:socket, name})
    partitions = :ets.lookup_element(ets, :partitions, 2)

    {collection, total} =
      Enum.map_reduce(0..(partitions - 1), 0, fn index, total ->
        try do
          sup = :ets.lookup_element(ets, index, 2)
          children = DynamicSupervisor.which_children(sup)
          {Enum.map(children, &elem(&1, 1)), total + length(children)}
        catch
          _, _ -> {[], total}
        end
      end)

    rounds = div(shutdown, interval)
    batch = max(ceil(total / rounds), 1)

    if total != 0 do
      Logger.info("Shutting down #{total} sockets in #{shutdown}ms in #{rounds} rounds")
    end

    for pids <- collection |> Stream.concat() |> Stream.chunk_every(batch) do
      {_pid, ref} =
        spawn_monitor(fn ->
          refs =
            for pid <- pids do
              send(pid, %Phoenix.Socket.Broadcast{event: "phx_draining"})
              Process.monitor(pid)
            end

          Enum.each(refs, fn _ ->
            receive do
              {:DOWN, _, _, _, _} -> :ok
            end
          end)
        end)

      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        interval -> Process.demonitor(ref, [:flush])
      end
    end
  end
end
