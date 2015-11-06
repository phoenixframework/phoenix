defmodule Phoenix.PubSub.Local do
  @moduledoc """
  PubSub implementation for handling local-node process groups.

  This module is used by Phoenix pubsub adapters to handle
  their local node subscriptions and it is usually not accessed
  directly. See `Phoenix.PubSub.PG2` for an example integration.
  """

  use GenServer
  alias Phoenix.Socket.Broadcast

  @doc """
  Starts the server.

    * `server_name` - The name to register the server under

  """
  def start_link(server_name, gc_name) do
    GenServer.start_link(__MODULE__, {server_name, gc_name}, name: server_name)
  end

  @doc """
  Subscribes the pid to the topic.

    * `pubsub_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, for example "users:123"
    * `opts` - The optional list of options. Supported options
      only include `:link` to link the subscriber to local

  ## Examples

      iex> subscribe(:pubsub_server, self, "foo")
      :ok

  """
  def subscribe(pubsub_server, pool_size, pid, topic, opts \\ []) when is_atom(pubsub_server) do
    {:ok, {topics, pids}} =
      pubsub_server
      |> local_for_pid(pid, pool_size)
      |> GenServer.call({:subscribe, pid, topic, opts})

    true = :ets.insert(topics, {topic, {pid, opts[:fastlane]}})
    true = :ets.insert(pids, {pid, topic})

    :ok
  end

  @doc """
  Unsubscribes the pid from the topic.

    * `pubsub_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> unsubscribe(:pubsub_server, self, "foo")
      :ok

  """
  def unsubscribe(pubsub_server, pool_size, pid, topic) when is_atom(pubsub_server) do
    {local_server, gc_server} =
      pid
      |> pid_to_shard(pool_size)
      |> pools_for_shard(pubsub_server)

    :ok = Phoenix.PubSub.GC.unsubscribe(pid, topic, local_server, gc_server)
  end

  @doc """
  Sends a message to all subscribers of a topic.

    * `pubsub_server` - The registered server name or pid
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> broadcast(:pubsub_server, self, "foo")
      :ok
      iex> broadcast(:pubsub_server, :none, "bar")
      :ok

  """
  def broadcast(pubsub_server, 1 = _pool_size, from, topic, msg)
    when is_atom(pubsub_server) do

    do_broadcast(pubsub_server, _shard = 0, from, topic, msg)
    :ok
  end
  def broadcast(pubsub_server, pool_size, from, topic, msg)
    when is_atom(pubsub_server) do

    parent = self
    for shard <- 0..(pool_size - 1) do
      Task.async(fn ->
        do_broadcast(pubsub_server, shard, from, topic, msg)
        Process.unlink(parent)
      end)
    end |> Enum.map(&Task.await(&1, :infinity))
    :ok
  end

  defp do_broadcast(pubsub_server, shard, from, topic, %Broadcast{event: event} = msg) do
    pubsub_server
    |> subscribers_with_fastlanes(topic, shard)
    |> Enum.reduce(%{}, fn
      {pid, _fastlanes}, cache when pid == from ->
        cache

      {pid, nil}, cache ->
        send(pid, msg)
      cache

      {pid, {fastlane_pid, serializer, event_intercepts}}, cache ->
      if event in event_intercepts do
        send(pid, msg)
        cache
      else
        case Map.fetch(cache, serializer) do
          {:ok, encoded_msg} ->
            send(fastlane_pid, encoded_msg)
            cache
          :error ->
            encoded_msg = serializer.fastlane!(msg)
            send(fastlane_pid, encoded_msg)
            Map.put(cache, serializer, encoded_msg)
        end
      end
    end)
  end
  defp do_broadcast(pubsub_server, shard, from, topic, msg) do
    pubsub_server
    |> subscribers(topic, shard)
    |> Enum.each(fn
      pid when pid == from -> :noop
      pid -> send(pid, msg)
    end)
  end

  @doc """
  Returns a set of subscribers pids for the given topic.

    * `pubsub_server` - The registered server name or pid
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> subscribers(:pubsub_server, "foo")
      [#PID<0.48.0>, #PID<0.49.0>]

  """
  def subscribers(pubsub_server, topic, shard) when is_atom(pubsub_server) do
    pubsub_server
    |> subscribers_with_fastlanes(topic, shard)
    |> Enum.map(fn {pid, _fastlanes} -> pid end)
  end

  @doc """
  Returns a set of subscribers pids for the given topic with fastlane tuples.
  See `subscribers/1` for more information.
  """
  def subscribers_with_fastlanes(pubsub_server, topic, shard) when is_atom(pubsub_server) do
    try do
      shard
      |> local_for_shard(pubsub_server)
      |> :ets.lookup_element(topic, 2)
    catch
      :error, :badarg -> []
    end
  end

  @doc false
  # This is an expensive and private operation. DO NOT USE IT IN PROD.
  def list(pubsub_server, shard) when is_atom(pubsub_server) do
    shard
    |> local_for_shard(pubsub_server)
    |> :ets.select([{{:'$1', :_}, [], [:'$1']}])
    |> Enum.uniq
  end

  @doc false
  # This is an expensive and private operation. DO NOT USE IT IN PROD.
  def subscription(pubsub_server, pool_size, pid) when is_atom(pubsub_server) do
    {_local, gc_server} =
      pid
      |> pid_to_shard(pool_size)
      |> pools_for_shard(pubsub_server)

    GenServer.call(gc_server, {:subscription, pid})
  end

  @doc false
  def local_name(pubsub_server, shard) do
    Module.concat(["#{pubsub_server}.Local#{shard}"])
  end

  @doc false
  def gc_name(pubsub_server, shard) do
    Module.concat(["#{pubsub_server}.GC#{shard}"])
  end

  def init({local, gc}) do
    ^local = :ets.new(local, [:duplicate_bag, :named_table, :public,
                              read_concurrency: true, write_concurrency: true])
    ^gc = :ets.new(gc, [:duplicate_bag, :named_table, :public,
                        read_concurrency: true, write_concurrency: true])

    Process.flag(:trap_exit, true)
    {:ok, %{topics: local, pids: gc, gc_server: gc}}
  end

  def handle_call({:subscribe, pid, _topic, opts}, _from, state) do
    if opts[:link], do: Process.link(pid)
    Process.monitor(pid)
    {:reply, {:ok, {state.topics, state.pids}}, state}
  end

  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    Phoenix.PubSub.GC.down(state.gc_server, pid)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp local_for_pid(pubsub_server, pid, pool_size) do
    pid
    |> pid_to_shard(pool_size)
    |> local_for_shard(pubsub_server)
  end

  defp local_for_shard(shard, pubsub_server) do
    {local_server, _gc_server} = pools_for_shard(shard, pubsub_server)
    local_server
  end

  defp pools_for_shard(shard, pubsub_server) do
    [{^shard, {_, _} = servers}] = :ets.lookup(pubsub_server, shard)
    servers
  end

  defp pid_to_shard(pid, shard_size) do
    pid
    |> pid_id()
    |> rem(shard_size)
  end
  defp pid_id(pid) do
    binary = :erlang.term_to_binary(pid)
    prefix = (byte_size(binary) - 9) * 8
    <<_::size(prefix), id::size(32), _::size(40)>> = binary

    id
  end
end
