defmodule Phoenix.PubSub do
  @moduledoc """
  Front-end to Phoenix pubsub layer.

  Used internally by Channels for pubsub broadcast but
  also provides an API for direct usage.

  ## Adapters

  Phoenix pubsub was designed to be flexible and support
  multiple backends. We currently ship with two backends:

    * `Phoenix.PubSub.PG2` - uses Distributed Elixir,
      directly exchanging notifications between servers

    * `Phoenix.PubSub.Redis` - uses Redis to exchange
      data between servers

  Pubsub adapters are often configured in your endpoint:

      config :my_app, MyApp.Endpoint,
        pubsub: [adapter: Phoenix.PubSub.PG2,
                 pool_size: 1,
                 name: MyApp.PubSub]

  The configuration above takes care of starting the
  pubsub backend and exposing its functions via the
  endpoint module. If no adapter but a name is given,
  nothing will be started, but the pubsub system will
  work by sending events and subscribing to the given
  name.

  ## Direct usage

  It is also possible to use `Phoenix.PubSub` directly
  or even run your own pubsub backends outside of an
  Endpoint.

  The first step is to start the adapter of choice in your
  supervision tree:

      supervisor(Phoenix.PubSub.Redis, [:my_redis_pubsub, host: "192.168.100.1"])

  The configuration above will start a Redis pubsub and
  register it with name `:my_redis_pubsub`.

  You can now use the functions in this module to subscribe
  and broadcast messages:

      iex> PubSub.subscribe MyApp.PubSub, self, "user:123"
      :ok
      iex> Process.info(self)[:messages]
      []
      iex> PubSub.broadcast MyApp.PubSub, "user:123", {:user_update, %{id: 123, name: "Shane"}}
      :ok
      iex> Process.info(self)[:messages]
      {:user_update, %{id: 123, name: "Shane"}}

  ## Implementing your own adapter

  PubSub adapters run inside their own supervision tree.
  If you are interested in providing your own adapter,  let's
  call it `Phoenix.PubSub.MyQueue`, the first step is to provide
  a supervisor module that receives the server name and a bunch
  of options on `start_link/2`:

      defmodule Phoenix.PubSub.MyQueue do
        def start_link(name, options) do
          Supervisor.start_link(__MODULE__, {name, options},
                                name: Module.concat(name, Supervisor))
        end

        def init({name, options}) do
          ...
        end
      end

  On `init/1`, you will define the supervision tree and use the given
  `name` to register the main pubsub process locally. This process must
  be able to handle the following GenServer calls:

    * `subscribe` - subscribes the given pid to the given topic
      sends:        `{:subscribe, pid, topic, opts}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

    * `unsubscribe` - unsubscribes the given pid from the given topic
      sends:        `{:unsubscribe, pid, topic}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

    * `broadcast` - broadcasts a message on the given topic
      sends:        `{:broadcast, :none | pid, topic, message}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

  ### Offloading work to clients via MFA response

  The `Phoenix.PubSub` API allows any of its functions to handle a
  response from the adapter matching `{:perform, {m, f, a}}`. The PubSub
  client will recursively invoke all MFA responses until a result is
  returned. This is useful for offloading work to clients without blocking
  your PubSub adapter. See `Phoenix.PubSub.PG2` implementation for examples.
  """

  defmodule BroadcastError do
    defexception [:message]
    def exception(msg) do
      %BroadcastError{message: "broadcast failed with #{inspect msg}"}
    end
  end

  @doc """
  Subscribes the pid to the PubSub adapter's topic.

    * `server` - The Pid registered name of the server
    * `pid` - The subscriber pid to receive pubsub messages
    * `topic` - The topic to subscribe to, ie: `"users:123"`
    * `opts` - The optional list of options. See below.

  ## Options

    * `:link` - links the subscriber to the pubsub adapter
    * `:fastlane` - Provides a fastlane path for the broadcasts for
      `%Phoenix.Socket.Broadcast{}` events. The fastlane process is
      notified of a cached message instead of the normal subscriber.
      Fastlane handlers must implement `fastlane/1` callbacks which accepts
      a `Phoenix.Socket.Broadcast` structs and returns a fastlaned format
      for the handler. For example:

          PubSub.subscribe(MyApp.PubSub, self(), "topic1",
            fastlane: {fast_pid, Phoenix.Transports.WebSocketSerializer, ["event1"]})
  """
  @spec subscribe(atom, pid, binary, Keyword.t) :: :ok | {:error, term}
  def subscribe(server, pid, topic, opts \\ []) when is_atom(server),
    do: call(server, :subscribe, [pid, topic, opts])

  @doc """
  Unsubscribes the pid from the PubSub adapter's topic.
  """
  @spec unsubscribe(atom, pid, binary) :: :ok | {:error, term}
  def unsubscribe(server, pid, topic) when is_atom(server),
    do: call(server, :unsubscribe, [pid, topic])

  @doc """
  Broadcasts message on given topic.
  """
  @spec broadcast(atom, binary, term) :: :ok | {:error, term}
  def broadcast(server, topic, message) when is_atom(server),
    do: call(server, :broadcast, [:none, topic, message])

  @doc """
  Broadcasts message on given topic.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  """
  @spec broadcast!(atom, binary, term) :: :ok | no_return
  def broadcast!(server, topic, message) do
    case broadcast(server, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Broadcasts message to all but `from_pid` on given topic.
  """
  @spec broadcast_from(atom, pid, binary, term) :: :ok | {:error, term}
  def broadcast_from(server, from_pid, topic, message) when is_atom(server) and is_pid(from_pid),
    do: call(server, :broadcast, [from_pid, topic, message])

  @doc """
  Broadcasts message to all but `from_pid` on given topic.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  """
  @spec broadcast_from(atom, pid, binary, term) :: :ok | no_return
  def broadcast_from!(server, from_pid, topic, message) when is_atom(server) and is_pid(from_pid) do
    case broadcast_from(server, from_pid, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  defp call(server, kind, args) do
    [{^kind, module, head}] = :ets.lookup(server, kind)
    apply(module, kind, head ++ args)
  end
end
