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

  def child_spec({_endpoint, name, opts} = tuple) do
    # The process should terminate within shutdown but,
    # in case it doesn't, we will be killed if we exceed
    # double of that
    %{
      id: {:terminator, name},
      start: {__MODULE__, :start_link, [tuple]},
      shutdown: Keyword.get(opts[:drainer], :shutdown, 30_000)
    }
  end

  def start_link(tuple) do
    GenServer.start_link(__MODULE__, tuple)
  end

  @impl true
  def init({endpoint, name, opts}) do
    Process.flag(:trap_exit, true)
    size = Keyword.get(opts[:drainer], :batch_size, 10_000)
    interval = Keyword.get(opts[:drainer], :batch_interval, 2_000)
    log_level = Keyword.get(opts[:drainer], :log, opts[:log] || :info)
    {:ok, {endpoint, name, size, interval, log_level}}
  end

  @impl true
  def terminate(_reason, {endpoint, name, size, interval, log_level}) do
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

    rounds = div(total, size) + 1

    for {pids, index} <-
          collection |> Stream.concat() |> Stream.chunk_every(size) |> Stream.with_index(1) do
      count = if index == rounds, do: length(pids), else: size

      :telemetry.execute(
        [:phoenix, :socket_drain],
        %{count: count, total: total, index: index, rounds: rounds},
        %{
          endpoint: endpoint,
          socket: name,
          interval: interval,
          log: log_level
        }
      )

      spawn(fn ->
        for pid <- pids do
          send(pid, %Phoenix.Socket.Broadcast{event: "phx_drain"})
        end
      end)

      if index < rounds do
        Process.sleep(interval)
      end
    end
  end
end
