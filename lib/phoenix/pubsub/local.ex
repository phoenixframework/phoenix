defmodule Phoenix.PubSub.Local do
  use GenServer

  @doc """
  Subscribes the pid to the topic

    * `pid` - The subscriber Pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> PubSub.Local.subscribe(self, "foo")
      :ok

  """
  def subscribe(pid, topic) do
    GenServer.call(__MODULE__, {:subscribe, pid, topic})
  end

  @doc """
  Unsubscribes the pid from the topic

    * `pid` - The subscriber Pid
    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> PubSub.Local.unsubscribe(self, "foo")
      :ok

  """
  def unsubscribe(pid, topic) do
    GenServer.call(__MODULE__, {:unsubscribe, pid, topic})
  end

  @doc """
  Sends a message to allow subscribers of a topic

    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> PubSub.Local.broadcast("foo")
      :ok
      iex> PubSub.Local.broadcast("bar")
      :no_topic

  """
  def broadcast(topic, msg) do
    GenServer.call(__MODULE__, {:broadcast, topic, msg})
  end

  @doc """
  Returns the `HashSet` of subscribers pids for the given topic

    * `topic` - The string topic, ie "users:123"

  ## Examples

      iex> PubSub.Local.subscribers("foo")
      #HashSet<[]>

  """
  def subscribers(topic) do
    GenServer.call(__MODULE__, {:subscribers, topic})
  end

  @doc """
  Starts the server
  """
  def start_link(server_name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: server_name)
  end

  @doc false
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc false
  def subscription(pid) do
    GenServer.call(__MODULE__, {:subscription, pid})
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
      {:ok, {_ref, topics}} -> {:reply, topics, state}
      :error                -> {:reply, :no_subscription, state}
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

  def handle_call({:broadcast, topic, msg}, _from, state) do
    case HashDict.fetch(state.topics, topic) do
      {:ok, pids} ->
        Enum.each(pids, fn pid -> send(pid, msg) end)
        {:reply, :ok, state}

      :error ->
        {:reply, :no_topic, state}
    end
  end

  def handle_info({:DOWN, ref, _type, pid, _info}, state) do
    {:noreply, drop_subscriber(state, pid, ref)}
  end

  def terminate(_reason, _state) do
    # TODO notify linked (?) subscribers?
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

            cond do
              Enum.any?(topic_pids) && Enum.any?(subd_topics) ->
                %{state | topics: HashDict.put(state.topics, topic, topic_pids),
                          pids: HashDict.put(state.pids, pid, {ref, subd_topics})}

              Enum.empty?(topic_pids) && Enum.empty?(subd_topics) ->
                Process.demonitor(ref)
                %{state | topics: HashDict.delete(state.topics, topic),
                          pids: HashDict.delete(state.pids, pid)}

              Enum.empty?(subd_topics) ->
                Process.demonitor(ref)
                %{state | topics: HashDict.put(state.topics, topic, topic_pids),
                          pids: HashDict.delete(state.pids, pid)}

              Enum.empty?(topic_pids) ->
                %{state | topics: HashDict.delete(state.topics, topic),
                          pids: HashDict.put(state.pids, pid, {ref, subd_topics})}
            end
        end
    end
  end

  defp drop_subscriber(state, pid, ref) do
    case HashDict.get(state.pids, pid) do
      {^ref, topics}    ->
        Enum.reduce(topics, state, fn topic, state ->
          drop_subscription(state, pid, topic)
        end)

      _ref_pid_mismatch -> state # handle chance that DOWN pid doesn't match ref
    end
  end
end
