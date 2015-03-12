defmodule Phoenix.PubSub do

  @moduledoc """
  Serves as a Notification and PubSub layer for broad use-cases. Used internally
  by Channels for pubsub broadcast.

  ## PubSub Adapter Contract
  PubSub adapters need to only implement `start_link/2` and respond to a few
  process-based messages to integrate with Phoenix.

  PubSub functions send the following messages:

    * `subscribe` -
       sends:        `{:subscribe, pid, topic, link}`
       respond with: `:ok | {:error, reason} {:perform, {m, f, a}}`

    * `unsubscribe` -
       sends:        `{:unsubscribe, pid, topic}`
       respond with: `:ok | {:error, reason} {:perform, {m, f, a}}`

    * `broadcast` -
       sends          `{:broadcast, :none, topic, message}`
       respond with: `:ok | {:error, reason} {:perform, {m, f, a}}`

  Additionally, adapters must implement `start_link/2` with the following format:

      def start_link(pubsub_server_name_to_locally_register, options)

  ### Offloading work to clients via MFA response

  The `Phoenix.PubSub` API allows any of its functions to handle a
  response from the adapter matching `{:perform, {m, f, a}}`. The PubSub
  client will recursively invoke all MFA responses until a result is
  returned. This is useful for offloading work to clients without blocking
  in your PubSub adapter. See `Phoenix.PubSub.PG2` for an example usage.

  ## Example

      iex> PubSub.subscribe MyApp.PubSub, self, "user:123"
      :ok
      iex> Process.info(self)[:messages]
      []
      iex> PubSub.broadcast MyApp.PubSub, "user:123", {:user_update, %{id: 123, name: "Shane"}}
      :ok
      iex> Process.info(self)[:messages]
      {:user_update, %{id: 123, name: "Shane"}}

  """

  defmodule BroadcastError do
    defexception [:message]
    def exception(msg) do
      %BroadcastError{message: "Broadcast failed with #{inspect msg}"}
    end
  end


  @doc """
  Subscribes the pid to the PubSub adapter's topic

    * `server` - The Pid registered name of the server
    * `pid` - The subscriber pid to receive pubsub messages
    * `topic` - The topic to subscribe to, ie: `"users:123"`
    * `opts` - The optional list of options. Supported options
               only include `:link` to link the subscriber to
               the pubsub adapter
  """
  def subscribe(server, pid, topic, opts \\ []),
    do: call(server, {:subscribe, pid, topic, opts})

  @doc """
  Unsubscribes the pid from the PubSub adapter's topic
  """
  def unsubscribe(server, pid, topic),
    do: call(server, {:unsubscribe, pid, topic})

  @doc """
  Broadcasts message on given topic
  """
  def broadcast(server, topic, message),
    do: call(server, {:broadcast, :none, topic, message})

  @doc """
  Broadcasts message on given topic
  raises `Phoenix.PubSub.BroadcastError` if broadcast fails
  """
  def broadcast!(server, topic, message) do
    case broadcast(server, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Broadcasts message to all but sender on given topic
  """
  def broadcast_from(server, from_pid, topic, message),
    do: call(server, {:broadcast, from_pid, topic, message})

  @doc """
  Broadcasts message to all but sender on given topic
  raises `Phoenix.PubSub.BroadcastError` if broadcast fails
  """
  def broadcast_from!(server, from_pid, topic, message) do
    case broadcast_from(server, from_pid, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  defp call(server, msg) do
    GenServer.call(server, msg) |> perform
  end

  defp perform({:perform, {mod, func, args}}) do
    apply(mod, func, args) |> perform
  end

  defp perform(result), do: result
end
