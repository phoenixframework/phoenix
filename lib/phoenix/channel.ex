defmodule Phoenix.Channel do
  @moduledoc ~S"""
  Defines a Phoenix Channel.

  Channels provide a means for bidirectional communication from clients that
  integrate with the `Phoenix.PubSub` layer for soft-realtime functionality.

  For a conceptual overview, see the [Channels guide](channels.html).

  ## Topics & Callbacks

  Every time you join a channel, you need to choose which particular topic you
  want to listen to. The topic is just an identifier, but by convention it is
  often made of two parts: `"topic:subtopic"`. Using the `"topic:subtopic"`
  approach pairs nicely with the `Phoenix.Socket.channel/3` allowing you to
  match on all topics starting with a given prefix by using a splat (the `*`
  character) as the last character in the topic pattern:

      channel "room:*", MyAppWeb.RoomChannel

  Any topic coming into the router with the `"room:"` prefix would dispatch
  to `MyAppWeb.RoomChannel` in the above example. Topics can also be pattern
  matched in your channels' `join/3` callback to pluck out the scoped pattern:

      # handles the special `"lobby"` subtopic
      def join("room:lobby", _payload, socket) do
        {:ok, socket}
      end

      # handles any other subtopic as the room ID, for example `"room:12"`, `"room:34"`
      def join("room:" <> room_id, _payload, socket) do
        {:ok, socket}
      end

  ## Authorization

  Clients must join a channel to send and receive PubSub events on that channel.
  Your channels must implement a `join/3` callback that authorizes the socket
  for the given topic. For example, you could check if the user is allowed to
  join that particular room.

  To authorize a socket in `join/3`, return `{:ok, socket}`.
  To refuse authorization in `join/3`, return `{:error, reply}`.

  ## Incoming Events

  After a client has successfully joined a channel, incoming events from the
  client are routed through the channel's `handle_in/3` callbacks. Within these
  callbacks, you can perform any action. Incoming callbacks must return the
  `socket` to maintain ephemeral state.

  Typically you'll either forward a message to all listeners with
  `broadcast!/3` or reply directly to a client event for request/response style
  messaging.

  General message payloads are received as maps:

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        ...
        {:reply, :ok, socket}
      end

  Binary data payloads are passed as a `{:binary, data}` tuple:

      def handle_in("file_chunk", {:binary, chunk}, socket) do
        ...
        {:reply, :ok, socket}
      end

  ## Broadcasts

  Here's an example of receiving an incoming `"new_msg"` event from one client,
  and broadcasting the message to all topic subscribers for this socket.

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast!(socket, "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

  ## Replies

  Replies are useful for acknowledging a client's message or responding with
  the results of an operation. A reply is sent only to the client connected to
  the current channel process. Behind the scenes, they include the client
  message `ref`, which allows the client to correlate the reply it receives
  with the message it sent.

  For example, imagine creating a resource and replying with the created record:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          post = Repo.insert!(changeset)
          response = MyAppWeb.PostView.render("show.json", %{post: post})
          {:reply, {:ok, response}, socket}
        else
          response = MyAppWeb.ChangesetView.render("errors.json", %{changeset: changeset})
          {:reply, {:error, response}, socket}
        end
      end

  Or you may just want to confirm that the operation succeeded:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          Repo.insert!(changeset)
          {:reply, :ok, socket}
        else
          {:reply, :error, socket}
        end
      end

  Binary data is also supported with replies via a `{:binary, data}` tuple:

      {:reply, {:ok, {:binary, bin}}, socket}

  If you don't want to send a reply to the client, you can return:

      {:noreply, socket}

  One situation when you might do this is if you need to reply later; see
  `reply/2`.

  ## Pushes

  Calling `push/3` allows you to send a message to the client which is not a
  reply to a specific client message. Because it is not a reply, a pushed
  message does not contain a client message `ref`; there is no prior client
  message to relate it to.

  Possible use cases include notifying a client that:
  - You've auto-saved the user's document
  - The user's game is ending soon
  - The IoT device's settings should be updated

  For example, you could `push/3` a message to the client in `handle_info/3`
  after receiving a `PubSub` message relevant to them.

      alias Phoenix.Socket.Broadcast
      def handle_info(%Broadcast{topic: _, event: event, payload: payload}, socket) do
        push(socket, event, payload)
        {:noreply, socket}
      end

  Push data can be given in the form of a map or a tagged `{:binary, data}`
  tuple:

      # client asks for their current rank. reply contains it, and client
      # is also pushed a leader board and a badge image
      def handle_in("current_rank", _, socket) do
        push(socket, "leaders", %{leaders: Game.get_leaders(socket.assigns.game_id)})
        push(socket, "badge", {:binary, File.read!(socket.assigns.badge_path)})
        {:reply, %{val: Game.get_rank(socket.assigns[:user])}, socket}
      end

  Note that in this example, `push/3` is called from `handle_in/3`; in this way
  you can essentially reply N times to a single message from the client. See
  `reply/2` for why this may be desirable.

  ## Intercepting Outgoing Events

  When an event is broadcasted with `broadcast/3`, each channel subscriber can
  choose to intercept the event and have their `handle_out/3` callback triggered.
  This allows the event's payload to be customized on a socket by socket basis
  to append extra information, or conditionally filter the message from being
  delivered. If the event is not intercepted with `Phoenix.Channel.intercept/1`,
  then the message is pushed directly to the client:

      intercept ["new_msg", "user_joined"]

      # for every socket subscribing to this topic, append an `is_editable`
      # value for client metadata.
      def handle_out("new_msg", msg, socket) do
        push(socket, "new_msg", Map.merge(msg,
          %{is_editable: User.can_edit_message?(socket.assigns[:user], msg)}
        ))
        {:noreply, socket}
      end

      # do not send broadcasted `"user_joined"` events if this socket's user
      # is ignoring the user who joined.
      def handle_out("user_joined", msg, socket) do
        unless User.ignoring?(socket.assigns[:user], msg.user_id) do
          push(socket, "user_joined", msg)
        end
        {:noreply, socket}
      end

  ## Broadcasting to an external topic

  In some cases, you will want to broadcast messages without the context of
  a `socket`. This could be for broadcasting from within your channel to an
  external topic, or broadcasting from elsewhere in your application like a
  controller or another process. Such can be done via your endpoint:

      # within channel
      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        ...
        broadcast_from!(socket, "new_msg", %{uid: uid, body: body})
        MyAppWeb.Endpoint.broadcast_from!(self(), "room:superadmin",
          "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

      # within controller
      def create(conn, params) do
        ...
        MyAppWeb.Endpoint.broadcast!("room:" <> rid, "new_msg", %{uid: uid, body: body})
        MyAppWeb.Endpoint.broadcast!("room:superadmin", "new_msg", %{uid: uid, body: body})
        redirect(conn, to: "/")
      end

  ## Terminate

  On termination, the channel callback `terminate/2` will be invoked with
  the error reason and the socket.

  If we are terminating because the client left, the reason will be
  `{:shutdown, :left}`. Similarly, if we are terminating because the
  client connection was closed, the reason will be `{:shutdown, :closed}`.

  If any of the callbacks return a `:stop` tuple, it will also
  trigger terminate with the reason given in the tuple.

  `terminate/2`, however, won't be invoked in case of errors nor in
  case of exits. This is the same behaviour as you find in Elixir
  abstractions like `GenServer` and others. Similar to `GenServer`,
  it would also be possible to `:trap_exit` to guarantee that `terminate/2`
  is invoked. This practice is not encouraged though.

  Generally speaking, if you want to clean something up, it is better to
  monitor your channel process and do the clean up from another process.
  All channel callbacks, including `join/3`, are called from within the
  channel process. Therefore, `self()` in any of them returns the PID to
  be monitored.

  ## Exit reasons when stopping a channel

  When the channel callbacks return a `:stop` tuple, such as:

      {:stop, :shutdown, socket}
      {:stop, {:error, :enoent}, socket}

  the second argument is the exit reason, which follows the same behaviour as
  standard `GenServer` exits.

  You have three options to choose from when shutting down a channel:

    * `:normal` - in such cases, the exit won't be logged and linked processes
      do not exit

    * `:shutdown` or `{:shutdown, term}` - in such cases, the exit won't be
      logged and linked processes exit with the same reason unless they're
      trapping exits

    * any other term - in such cases, the exit will be logged and linked
      processes exit with the same reason unless they're trapping exits

  ## Subscribing to external topics

  Sometimes you may need to programmatically subscribe a socket to external
  topics in addition to the internal `socket.topic`. For example,
  imagine you have a bidding system where a remote client dynamically sets
  preferences on products they want to receive bidding notifications on.
  Instead of requiring a unique channel process and topic per
  preference, a more efficient and simple approach would be to subscribe a
  single channel to relevant notifications via your endpoint. For example:

      defmodule MyAppWeb.Endpoint.NotificationChannel do
        use Phoenix.Channel

        def join("notification:" <> user_id, %{"ids" => ids}, socket) do
          topics = for product_id <- ids, do: "product:#{product_id}"

          {:ok, socket
                |> assign(:topics, [])
                |> put_new_topics(topics)}
        end

        def handle_in("watch", %{"product_id" => id}, socket) do
          {:reply, :ok, put_new_topics(socket, ["product:#{id}"])}
        end

        def handle_in("unwatch", %{"product_id" => id}, socket) do
          {:reply, :ok, MyAppWeb.Endpoint.unsubscribe("product:#{id}")}
        end

        defp put_new_topics(socket, topics) do
          Enum.reduce(topics, socket, fn topic, acc ->
            topics = acc.assigns.topics
            if topic in topics do
              acc
            else
              :ok = MyAppWeb.Endpoint.subscribe(topic)
              assign(acc, :topics, [topic | topics])
            end
          end)
        end
      end

  Note: the caller must be responsible for preventing duplicate subscriptions.
  After calling `subscribe/1` from your endpoint, the same flow applies to
  handling regular Elixir messages within your channel. Most often, you'll
  simply relay the `%Phoenix.Socket.Broadcast{}` event and payload:

      alias Phoenix.Socket.Broadcast
      def handle_info(%Broadcast{topic: _, event: event, payload: payload}, socket) do
        push(socket, event, payload)
        {:noreply, socket}
      end

  ## Hibernation

  From Erlang/OTP 20, channels automatically hibernate to save memory
  after 15_000 milliseconds of inactivity. This can be customized by
  passing the `:hibernate_after` option to `use Phoenix.Channel`:

      use Phoenix.Channel, hibernate_after: 60_000

  You can also set it to `:infinity` to fully disable it.

  ## Shutdown

  You can configure the shutdown behavior of each channel used when your
  application is shutting down by setting the `:shutdown` value on use:

      use Phoenix.Channel, shutdown: 5_000

  It defaults to 5_000. The supported values are described under the
  in the `Supervisor` module docs.

  ## Logging

  By default, channel `"join"` and `"handle_in"` events are logged, using
  the level `:info` and `:debug`, respectively. Logs can be customized per
  event type or disabled by setting the `:log_join` and `:log_handle_in`
  options when using `Phoenix.Channel`. For example, the following
  configuration logs join events as `:info`, but disables logging for
  incoming events:

      use Phoenix.Channel, log_join: :info, log_handle_in: false

  """
  alias Phoenix.Socket
  alias Phoenix.Channel.Server

  @type payload :: map | term | {:binary, binary}
  @type reply :: status :: atom | {status :: atom, response :: payload}
  @type socket_ref ::
          {transport_pid :: Pid, serializer :: module, topic :: binary, ref :: binary,
           join_ref :: binary}

  @doc """
  Handle channel joins by `topic`.

  To authorize a socket, return `{:ok, socket}` or `{:ok, reply, socket}`. To
  refuse authorization, return `{:error, reason}`.

  Payloads are serialized before sending with the configured serializer.

  ## Example

      def join("room:lobby", payload, socket) do
        if authorized?(payload) do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

  """
  @callback join(topic :: binary, payload :: payload, socket :: Socket.t()) ::
              {:ok, Socket.t()}
              | {:ok, reply :: payload, Socket.t()}
              | {:error, reason :: map}

  @doc """
  Handle incoming `event`s.

  Payloads are serialized before sending with the configured serializer.

  ## Example

      def handle_in("ping", payload, socket) do
        {:reply, {:ok, payload}, socket}
      end
  """
  @callback handle_in(event :: String.t(), payload :: payload, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:noreply, Socket.t(), timeout | :hibernate}
              | {:reply, reply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}
              | {:stop, reason :: term, reply, Socket.t()}

  @doc """
  Intercepts outgoing `event`s.

  See `intercept/1`.
  """
  @callback handle_out(event :: String.t(), payload :: payload, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:noreply, Socket.t(), timeout | :hibernate}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Handle regular Elixir process messages.

  See `c:GenServer.handle_info/2`.
  """
  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Handle regular GenServer call messages.

  See `c:GenServer.handle_call/3`.
  """
  @callback handle_call(msg :: term, from :: {pid, tag :: term}, socket :: Socket.t()) ::
              {:reply, response :: term, Socket.t()}
              | {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Handle regular GenServer cast messages.

  See `c:GenServer.handle_cast/2`.
  """
  @callback handle_cast(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc false
  @callback code_change(old_vsn, Socket.t(), extra :: term) ::
              {:ok, Socket.t()}
              | {:error, reason :: term}
            when old_vsn: term | {:down, term}

  @doc """
  Invoked when the channel process is about to exit.

  See `c:GenServer.terminate/2`.
  """
  @callback terminate(
              reason :: :normal | :shutdown | {:shutdown, :left | :closed | term},
              Socket.t()
            ) ::
              term

  @optional_callbacks handle_in: 3,
                      handle_out: 3,
                      handle_info: 2,
                      handle_call: 3,
                      handle_cast: 2,
                      code_change: 3,
                      terminate: 2

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)
      @behaviour unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @phoenix_intercepts []
      @phoenix_log_join Keyword.get(opts, :log_join, :info)
      @phoenix_log_handle_in Keyword.get(opts, :log_handle_in, :debug)
      @phoenix_hibernate_after Keyword.get(opts, :hibernate_after, 15_000)
      @phoenix_shutdown Keyword.get(opts, :shutdown, 5000)

      import unquote(__MODULE__)
      import Phoenix.Socket, only: [assign: 3, assign: 2]

      def child_spec(init_arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]},
          shutdown: @phoenix_shutdown,
          restart: :temporary
        }
      end

      def start_link(triplet) do
        GenServer.start_link(Phoenix.Channel.Server, triplet,
          hibernate_after: @phoenix_hibernate_after
        )
      end

      def __socket__(:private) do
        %{log_join: @phoenix_log_join, log_handle_in: @phoenix_log_handle_in}
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def __intercepts__, do: @phoenix_intercepts
    end
  end

  @doc """
  Defines which Channel events to intercept for `handle_out/3` callbacks.

  By default, broadcasted events are pushed directly to the client, but
  intercepting events gives your channel a chance to customize the event
  for the client to append extra information or filter the message from being
  delivered.

  *Note*: intercepting events can introduce significantly more overhead if a
  large number of subscribers must customize a message since the broadcast will
  be encoded N times instead of a single shared encoding across all subscribers.

  ## Examples

      intercept ["new_msg"]

      def handle_out("new_msg", payload, socket) do
        push(socket, "new_msg", Map.merge(payload,
          is_editable: User.can_edit_message?(socket.assigns[:user], payload)
        ))
        {:noreply, socket}
      end

  `handle_out/3` callbacks must return one of:

      {:noreply, Socket.t} |
      {:noreply, Socket.t, timeout | :hibernate} |
      {:stop, reason :: term, Socket.t}

  """
  defmacro intercept(events) do
    quote do
      @phoenix_intercepts unquote(events)
    end
  end

  @doc false
  def __on_definition__(env, :def, :handle_out, [event, _payload, _socket], _, _)
      when is_binary(event) do
    unless event in Module.get_attribute(env.module, :phoenix_intercepts) do
      IO.write(
        "#{Path.relative_to(env.file, File.cwd!())}:#{env.line}: [warning] " <>
          "An intercept for event \"#{event}\" has not yet been defined in #{env.module}.handle_out/3. " <>
          "Add \"#{event}\" to your list of intercepted events with intercept/1"
      )
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
    :ok
  end

  @doc """
  Broadcast an event to all subscribers of the socket topic.

  The event's message must be a serializable map or a tagged `{:binary, data}`
  tuple where `data` is binary data.

  ## Examples

      iex> broadcast(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> broadcast(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def broadcast(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast(pubsub_server, topic, event, message)
  end

  @doc """
  Same as `broadcast/3`, but raises if broadcast fails.
  """
  def broadcast!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast!(pubsub_server, topic, event, message)
  end

  @doc """
  Broadcast event from pid to all subscribers of the socket topic.

  The channel that owns the socket will not receive the published
  message. The event's message must be a serializable map or a tagged
  `{:binary, data}` tuple where `data` is binary data.

  ## Examples

      iex> broadcast_from(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> broadcast_from(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} =
      assert_joined!(socket)

    Server.broadcast_from(pubsub_server, channel_pid, topic, event, message)
  end

  @doc """
  Same as `broadcast_from/3`, but raises if broadcast fails.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} =
      assert_joined!(socket)

    Server.broadcast_from!(pubsub_server, channel_pid, topic, event, message)
  end

  @doc """
  Sends an event directly to the connected client without requiring a prior
  message from the client.

  The event's message must be a serializable map or a tagged `{:binary, data}`
  tuple where `data` is binary data.

  Note that unlike some in client libraries, this server-side `push/3` does not
  return a reference. If you need to get a reply from the client and to
  correlate that reply with the message you pushed, you'll need to include a
  unique identifier in the message, track it in the Channel's state, have the
  client include it in its reply, and examine the ref when the reply comes to
  `handle_in/3`.

  ## Examples

      iex> push(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> push(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def push(socket, event, message) do
    %{transport_pid: transport_pid, topic: topic} = assert_joined!(socket)
    Server.push(transport_pid, socket.join_ref, topic, event, message, socket.serializer)
  end

  @doc """
  Replies asynchronously to a socket push.

  The usual way of replying to a client's message is to return a tuple from `handle_in/3`
  like:

      {:reply, {status, payload}, socket}

  But sometimes you need to reply to a push asynchronously - that is, after
  your `handle_in/3` callback completes. For example, you might need to perform
  work in another process and reply when it's finished.

  You can do this by generating a reference to the socket with `socket_ref/1`
  and calling `reply/2` with that ref when you're ready to reply.

  *Note*: A `socket_ref` is required so the `socket` itself is not leaked
  outside the channel. The `socket` holds information such as assigns and
  transport configuration, so it's important to not copy this information
  outside of the channel that owns it.

  Technically, `reply/2` will allow you to reply multiple times to the same
  client message, and each reply will include the client message `ref`. But the
  client may expect only one reply; in that case, `push/3` would be preferable
  for the additional messages.

  Payloads are serialized before sending with the configured serializer.

  ## Examples

      def handle_in("work", payload, socket) do
        Worker.perform(payload, socket_ref(socket))
        {:noreply, socket}
      end

      def handle_info({:work_complete, result, ref}, socket) do
        reply(ref, {:ok, result})
        {:noreply, socket}
      end

  """
  @spec reply(socket_ref, reply) :: :ok
  def reply(socket_ref, status) when is_atom(status) do
    reply(socket_ref, {status, %{}})
  end

  def reply({transport_pid, serializer, topic, ref, join_ref}, {status, payload}) do
    Server.reply(transport_pid, join_ref, ref, topic, {status, payload}, serializer)
  end

  @doc """
  Generates a `socket_ref` for an async reply.

  See `reply/2` for example usage.
  """
  @spec socket_ref(Socket.t()) :: socket_ref
  def socket_ref(%Socket{joined: true, ref: ref} = socket) when not is_nil(ref) do
    {socket.transport_pid, socket.serializer, socket.topic, ref, socket.join_ref}
  end

  def socket_ref(_socket) do
    raise ArgumentError, """
    socket refs can only be generated for a socket that has joined with a push ref
    """
  end

  defp assert_joined!(%Socket{joined: true} = socket) do
    socket
  end

  defp assert_joined!(%Socket{joined: false}) do
    raise """
    push/3, reply/2, and broadcast/3 can only be called after the socket has finished joining.
    To push a message on join, send to self and handle in handle_info/2. For example:

        def join(topic, auth_msg, socket) do
          ...
          send(self, :after_join)
          {:ok, socket}
        end

        def handle_info(:after_join, socket) do
          push(socket, "feed", %{list: feed_items(socket)})
          {:noreply, socket}
        end

    """
  end
end
