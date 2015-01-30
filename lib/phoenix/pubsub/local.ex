defmodule Phoenix.PubSub.Local do
  use GenServer

  @moduledoc """
  PubSub implementation for handling local-node process groups

  This modules is used by Phoenix pubsub adapters to handle their
  local node topic subscriptions. See `Phoenix.PubSub.PG2`
  for an example integration.
  """

  @doc """
  Starts the server

    * `server_name` - The name to registered the server under

  """
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  @doc """
  Subscribes the pid to the topic

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber Pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> subscribe(:local_server, self, "foo")
      :ok

  """
  def subscribe(local_server, pid, topic) do
    GenServer.call(local_server, {:subscribe, pid, topic})
  end

  @doc """
  Unsubscribes the pid from the topic

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber Pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> unsubscribe(:local_server, self, "foo")
      :ok

  """
  def unsubscribe(local_server, pid, topic) do
    GenServer.call(local_server, {:unsubscribe, pid, topic})
  end

  @doc """
  Sends a message to allow subscribers of a topic

    * `local_server` - The registered server name or pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> broadcast(:local_server, "foo")
      :ok
      iex> broadcast(:local_server, "bar")
      :no_topic

  """
  def broadcast(local_server, topic, msg) do
    GenServer.call(local_server, {:broadcast, :none, topic, msg})
  end

  @doc """
  Returns the `HashSet` of subscribers pids for the given topic

    * `local_server` - The registered server name or pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> subscribers(:local_server, "foo")
      #HashSet<[]>

  """
  def subscribers(local_server, topic) do
    GenServer.call(local_server, {:subscribers, topic})
  end

  @doc false
  def list(local_server) do
    GenServer.call(local_server, :list)
  end

  @doc false
  def subscription(local_server, pid) do
    GenServer.call(local_server, {:subscription, pid})
  end

  @doc false
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %{topics: HashDict.new, pids: HashDict.new}}
  end

  def handle_call(:list, _from, state) do
    {:reply, Dict.keys(state.topics), state}
  end

  def handle_call({:subscription, pid}, _from, state) do
    case HashDict.fetch(state.pids, pid) do
      {:ok, {_ref, topics}} -> {:reply, {:ok, topics}, state}
      :error                -> {:reply, :error, state}
    end
  end

  def handle_call({:subscribers, topic}, _from, state) do
    {:reply, HashDict.get(state.topics, topic, HashSet.new), state}
  end

  def handle_call({:subscribe, pid, topic}, _from, state) do
    {:reply, :ok, put_subscription(state, pid, topic)}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    {:reply, :ok, drop_subscription(state, pid, topic)}
  end

  def handle_call({:broadcast, from_pid, topic, msg}, _from, state) do
    case HashDict.fetch(state.topics, topic) do
      {:ok, pids} ->
        Enum.each(pids, fn
          pid when pid != from_pid -> send(pid, msg)
          _ -> :ok
        end)
        {:reply, :ok, state}

      :error ->
        {:reply, :no_topic, state}
    end
  end

  def handle_info({:DOWN, ref, _type, pid, _info}, state) do
    {:noreply, drop_subscriber(state, pid, ref)}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp put_subscription(state, pid, topic) do
    subscription = case HashDict.fetch(state.pids, pid) do
      {:ok, {ref, topics}} ->
        {ref, HashSet.put(topics, topic)}
      :error ->
        {Process.monitor(pid), HashSet.put(HashSet.new, topic)}
    end

    topic_pids = case HashDict.fetch(state.topics, topic) do
      {:ok, pids} -> HashSet.put(pids, pid)
      :error      -> HashSet.put(HashSet.new, pid)
    end

    %{state | topics: HashDict.put(state.topics, topic, topic_pids),
              pids: HashDict.put(state.pids, pid, subscription)}
  end

  defp drop_subscription(state, pid, topic) do
    case HashDict.fetch(state.topics, topic) do
      :error      -> state
      {:ok, topic_pids} ->
        case HashDict.fetch(state.pids, pid) do
          :error      -> state
          {:ok, {ref, subd_topics}} ->
            topic_pids  = HashSet.delete(topic_pids, pid)
            subd_topics = HashSet.delete(subd_topics, topic)

            topics =
              if Enum.any?(topic_pids) do
                HashDict.put(state.topics, topic, topic_pids)
              else
                HashDict.delete(state.topics, topic)
              end

            pids =
              if Enum.any?(subd_topics) do
                HashDict.put(state.pids, pid, {ref, subd_topics})
              else
                Process.demonitor(ref)
                HashDict.delete(state.pids, pid)
              end

            %{state | topics: topics, pids: pids}
        end
    end
  end

  defp drop_subscriber(state, pid, ref) do
    case HashDict.get(state.pids, pid) do
      {^ref, topics}    ->
        Enum.reduce(topics, state, fn topic, state ->
          drop_subscription(state, pid, topic)
        end)

      _ref_pid_mismatch -> state
    end
  end
end
