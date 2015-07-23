defmodule Phoenix.PubSub.Local do
  use GenServer

  @moduledoc """
  PubSub implementation for handling local-node process groups.

  This module is used by Phoenix pubsub adapters to handle
  their local node subscriptions and it is usually not accessed
  directly. See `Phoenix.PubSub.PG2` for an example integration.
  """

  @doc """
  Starts the server.

    * `server_name` - The name to register the server under

  """
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, server_name, name: server_name)
  end

  @doc """
  Subscribes the pid to the topic.

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, ie "users:123"
    * `opts` - The optional list of options. Supported options
      only include `:link` to link the subscriber to local

  ## Examples

      iex> subscribe(:local_server, self, "foo")
      :ok

  """
  def subscribe(local_server, pid, topic, opts \\ []) when is_atom(local_server) do
    GenServer.call(local_server, {:subscribe, pid, topic, opts})
  end

  @doc """
  Unsubscribes the pid from the topic.

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> unsubscribe(:local_server, self, "foo")
      :ok

  """
  def unsubscribe(local_server, pid, topic) when is_atom(local_server) do
    GenServer.call(local_server, {:unsubscribe, pid, topic})
  end

  @doc """
  Sends a message to all subscribers of a topic.

    * `local_server` - The registered server name or pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> broadcast(:local_server, self, "foo")
      :ok
      iex> broadcast(:local_server, :none, "bar")
      :ok

  """
  def broadcast(local_server, from, topic, msg) when is_atom(local_server) do
    local_server
    |> subscribers(topic)
    |> Enum.reduce(%{}, fn
      {pid, _fastlanes}, cache when pid == from ->
        cache

      {pid, nil}, cache ->
        send(pid, msg)
        cache

      {pid, {fastlane_handler, func, args}}, cache ->
        case apply(fastlane_handler, func, [topic, msg, cache | args]) do
          :noop ->
            send(pid, msg)
            cache
          {:sent, cache} -> cache
        end
    end)
    :ok
  end

  @doc """
  Returns a set of subscribers pids for the given topic.

    * `local_server` - The registered server name or pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> subscribers(:local_server, "foo")
      [#PID<0.48.0>, #PID<0.49.0>]

  """
  def subscribers(local_server, topic) when is_atom(local_server) do
    try do
      :ets.lookup_element(local_server, topic, 2)
    catch
      :error, :badarg -> []
    end
  end

  @doc false
  # This is an expensive and private operation. DO NOT USE IT IN PROD.
  def list(local_server) when is_atom(local_server) do
    local_server
    |> :ets.select([{{:'$1', :_}, [], [:'$1']}])
    |> Enum.uniq
  end

  @doc false
  # This is a private operation. DO NOT USE IT IN PROD.
  def subscription(local_server, pid) when is_atom(local_server) do
    GenServer.call(local_server, {:subscription, pid})
  end

  def init(name) do
    ^name = :ets.new(name, [:bag, :named_table, read_concurrency: true])
    Process.flag(:trap_exit, true)
    {:ok, %{topics: name, pids: HashDict.new}}
  end

  def handle_call({:subscription, pid}, _from, state) do
    case HashDict.fetch(state.pids, pid) do
      {:ok, {_ref, topics, fastlanes}} -> {:reply, {:ok, topics, fastlanes}, state}
      :error                           -> {:reply, :error, state}
    end
  end

  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    if opts[:link], do: Process.link(pid)
    {:reply, :ok, put_subscription(state, pid, topic, opts[:fastlane])}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, :ok, drop_subscription(state, pid, topic)}
  end

  def handle_info({:DOWN, ref, _type, pid, _info}, state) do
    {:noreply, drop_subscriber(state, pid, ref)}
  end

  def handle_info({:EXIT, _linked_pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp put_subscription(state, pid, topic, fastlane) do
    subscription = case HashDict.fetch(state.pids, pid) do
      {:ok, {ref, topics, fastlanes}} ->
        fastlanes = if fastlane, do: HashDict.put(fastlanes, topic, fastlane),
                                 else: fastlanes
        {ref, HashSet.put(topics, topic), fastlanes}
      :error ->
        fastlanes = if fastlane, do: HashDict.put(HashDict.new, topic, fastlane),
                                 else: HashDict.new
        {Process.monitor(pid), HashSet.put(HashSet.new, topic), fastlanes}
    end

    true = :ets.insert(state.topics, {topic, {pid, fastlane}})
    %{state | pids: HashDict.put(state.pids, pid, subscription)}
  end

  defp drop_subscription(state, pid, topic) do
    case HashDict.fetch(state.pids, pid) do
      {:ok, {ref, subd_topics, fastlanes}} ->
        subd_topics = HashSet.delete(subd_topics, topic)
        {fastlane, fastlanes} = HashDict.pop(fastlanes, topic)

        pids =
          if Enum.any?(subd_topics) do
            HashDict.put(state.pids, pid, {ref, subd_topics, fastlanes})
          else
            Process.demonitor(ref, [:flush])
            HashDict.delete(state.pids, pid)
          end

        true = :ets.delete_object(state.topics, {topic, {pid, fastlane}})
        %{state | pids: pids}

      :error ->
        state
    end
  end

  defp drop_subscriber(state, pid, ref) do
    case HashDict.get(state.pids, pid) do
      {^ref, topics, fastlanes} ->
        for topic <- topics do
          fastlane = HashDict.get(fastlanes, topic)
          true = :ets.delete_object(state.topics, {topic, {pid, fastlane}})
        end
        Process.demonitor(ref, [:flush])
        %{state | pids: HashDict.delete(state.pids, pid)}

      _ref_pid_mismatch ->
        state
    end
  end
end
