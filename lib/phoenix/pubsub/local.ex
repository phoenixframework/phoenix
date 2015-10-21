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
  def start_link(server_name) do
    GenServer.start_link(__MODULE__, server_name, name: server_name)
  end

  @doc """
  Subscribes the pid to the topic.

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, for example "users:123"
    * `opts` - The optional list of options. Supported options
      only include `:link` to link the subscriber to local

  ## Examples

      iex> subscribe(:local_server, self, "foo")
      :ok

  """
  def subscribe(local_server, pid, topic, opts \\ []) when is_atom(local_server) do
    :ok = GenServer.call(local_server, {:subscribe, pid, opts[:link]})
    true = :ets.insert(local_server, {topic, {pid, opts[:fastlane]}})
    :ok
  end

  @doc """
  Unsubscribes the pid from the topic.

    * `local_server` - The registered server name or pid
    * `pid` - The subscriber pid
    * `topic` - The string topic, for example "users:123"

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
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> broadcast(:local_server, self, "foo")
      :ok
      iex> broadcast(:local_server, :none, "bar")
      :ok

  """
  def broadcast(local_server, from, topic, %Broadcast{event: event} = msg)
    when is_atom(local_server) do

    local_server
    |> subscribers_with_fastlanes(topic)
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
    :ok
  end

  def broadcast(local_server, from, topic, msg) when is_atom(local_server) do
    local_server
    |> subscribers(topic)
    |> Enum.each(fn
      pid when pid == from -> :noop
      pid -> send(pid, msg)
    end)
    :ok
  end

  @doc """
  Returns a set of subscribers pids for the given topic.

    * `local_server` - The registered server name or pid
    * `topic` - The string topic, for example "users:123"

  ## Examples

      iex> subscribers(:local_server, "foo")
      [#PID<0.48.0>, #PID<0.49.0>]

  """
  def subscribers(local_server, topic) when is_atom(local_server) do
    local_server
    |> subscribers_with_fastlanes(topic)
    |> Enum.map(fn {pid, _fastlanes} -> pid end)
  end

  @doc """
  Returns a set of subscribers pids for the given topic with fastlane tuples.
  See `subscribers/1` for more information.
  """
  def subscribers_with_fastlanes(local_server, topic) when is_atom(local_server) do
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
  # This is an expensive and private operation. DO NOT USE IT IN PROD.
  def subscription(local_server, pid) when is_atom(local_server) do
    local_server
    |> :ets.select([{{:'$1', {pid, :_}}, [], [:'$1']}])
    |> Enum.uniq
  end

  def init(name) do
    ^name = :ets.new(name, [:bag, :named_table, :public,
                            read_concurrency: true, write_concurrency: true])
    Process.flag(:trap_exit, true)
    {:ok, name}
  end

  def handle_call({:subscribe, pid, link}, _from, state) do
    if link, do: Process.link(pid)
    Process.monitor(pid)
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    true = :ets.match_delete(state, {topic, {pid, :_}})
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    true = :ets.match_delete(state, {:_, {pid, :_}})
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
