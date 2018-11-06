defmodule Phoenix.Channel do
  @moduledoc ~S"""
  Defines a Phoenix Channel.

  Channels provide a means for bidirectional communication from clients that
  integrate with the `Phoenix.PubSub` layer for soft-realtime functionality.

  ## Topics & Callbacks

  Every time you join a channel, you need to choose which particular topic you
  want to listen to. The topic is just an identifier, but by convention it is
  often made of two parts: `"topic:subtopic"`. Using the `"topic:subtopic"`
  approach pairs nicely with the `Phoenix.Socket.channel/2` allowing you to
  match on all topics starting with a given prefix:

      channel "room:*", MyApp.RoomChannel

  Any topic coming into the router with the `"room:"` prefix would dispatch
  to `MyApp.RoomChannel` in the above example. Topics can also be pattern
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
  callbacks, you can perform any action. Typically you'll either forward a
  message to all listeners with `broadcast!/3`, or push a message directly down
  the socket with `push/3`. Incoming callbacks must return the `socket` to
  maintain ephemeral state.

  Here's an example of receiving an incoming `"new_msg"` event from one client,
  and broadcasting the message to all topic subscribers for this socket.

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast!(socket, "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

  You can also push a message directly down the socket:

      # client asks for their current rank, push sent directly as a new event.
      def handle_in("current_rank", socket) do
        push(socket, "current_rank", %{val: Game.get_rank(socket.assigns[:user])})
        {:noreply, socket}
      end

  ## Replies

  In addition to pushing messages out when you receive a `handle_in` event,
  you can also reply directly to a client event for request/response style
  messaging. This is useful when a client must know the result of an operation
  or to simply ack messages.

  For example, imagine creating a resource and replying with the created record:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          post = Repo.insert!(changeset)
          response = MyApp.PostView.render("show.json", %{post: post})
          {:reply, {:ok, response}, socket}
        else
          response = MyApp.ChangesetView.render("errors.json", %{changeset: changeset})
          {:reply, {:error, response}, socket}
        end
      end

  Alternatively, you may just want to ack the status of the operation:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          Repo.insert!(changeset)
          {:reply, :ok, socket}
        else
          {:reply, :error, socket}
        end
      end

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
        MyApp.Endpoint.broadcast_from!(self(), "room:superadmin",
          "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

      # within controller
      def create(conn, params) do
        ...
        MyApp.Endpoint.broadcast!("room:" <> rid, "new_msg", %{uid: uid, body: body})
        MyApp.Endpoint.broadcast!("room:superadmin", "new_msg", %{uid: uid, body: body})
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
  abstractions like `GenServer` and others. Typically speaking, if you
  want to clean something up, it is better to monitor your channel
  process and do the clean up from another process.  Similar to GenServer,
  it would also be possible `:trap_exit` to guarantee that `terminate/2`
  is invoked. This practice is not encouraged though.

  ## Exit reasons when stopping a channel

  When the channel callbacks return a `:stop` tuple, such as:

      {:stop, :shutdown, socket}
      {:stop, {:error, :enoent}, socket}

  the second argument is the exit reason, which follows the same behaviour as
  standard `GenServer` exits.

  You have three options to choose from when shutting down a channel:

    * `:normal` - in such cases, the exit won't be logged, there is no restart
      in transient mode, and linked processes do not exit

    * `:shutdown` or `{:shutdown, term}` - in such cases, the exit won't be
      logged, there is no restart in transient mode, and linked processes exit
      with the same reason unless they're trapping exits

    * any other term - in such cases, the exit will be logged, there are
      restarts in transient mode, and linked processes exit with the same reason
      unless they're trapping exits

  ## Subscribing to external topics

  Sometimes you may need to programmatically subscribe a socket to external
  topics in addition to the the internal `socket.topic`. For example,
  imagine you have a bidding system where a remote client dynamically sets
  preferences on products they want to receive bidding notifications on.
  Instead of requiring a unique channel process and topic per
  preference, a more efficient and simple approach would be to subscribe a
  single channel to relevant notifications via your endpoint. For example:

      defmodule MyApp.Endpoint.NotificationChannel do
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
          {:reply, :ok, MyApp.Endpoint.unsubscribe("product:#{id}")}
        end

        defp put_new_topics(socket, topics) do
          Enum.reduce(topics, socket, fn topic, acc ->
            topics = acc.assigns.topics
            if topic in topics do
              acc
            else
              :ok = MyApp.Endpoint.subscribe(topic)
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

  @type reply :: status :: atom | {status :: atom, response :: map}
  @type socket_ref :: {transport_pid :: Pid, serializer :: module,
                       topic :: binary, ref :: binary, join_ref :: binary}

  @doc """
  Handle channel joins by `topic`.

  To authorize a socket, return `{:ok, socket}` or `{:ok, reply, socket}`. To
  refuse authorization, return `{:error, reason}`.

  ## Example

      def join("room:lobby", payload, socket) do
        if authorized?(payload) do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

  """
  @callback join(topic :: binary, payload :: map, socket :: Socket.t) ::
              {:ok, Socket.t} |
              {:ok, reply :: map, Socket.t} |
              {:error, reason :: map}

  @doc """
  Handle incoming `event`s.

  ## Example

      def handle_in("ping", payload, socket) do
        {:reply, {:ok, payload}, socket}
      end

  """
  @callback handle_in(event :: String.t, payload :: map, socket :: Socket.t) ::
              {:noreply, Socket.t} |
              {:noreply, Socket.t, timeout | :hibernate} |
              {:reply, reply, Socket.t} |
              {:stop, reason :: term, Socket.t} |
              {:stop, reason :: term, reply, Socket.t}

  @doc """
  Intercepts outgoing `event`s.

  See `intercept/1`.
  """
  @callback handle_out(event :: String.t, payload :: map, socket :: Socket.t) ::
              {:noreply, Socket.t} |
              {:noreply, Socket.t, timeout | :hibernate} |
              {:stop, reason :: term, Socket.t}

  @doc """
  Handle regular Elixir process messages.

  See `GenServer.handle_info/2`.
  """
  @callback handle_info(msg :: term, socket :: Socket.t) ::
              {:noreply, Socket.t} |
              {:stop, reason :: term, Socket.t}

  @doc false
  @callback code_change(old_vsn, Socket.t, extra :: term) ::
              {:ok, Socket.t} |
              {:error, reason :: term} when old_vsn: term | {:down, term}

  @doc """
  Invoked when the channel process is about to exit.

  See `GenServer.terminate/2`.
  """
  @callback terminate(reason :: :normal | :shutdown | {:shutdown, :left | :closed | term}, Socket.t) ::
              term

  @optional_callbacks handle_in: 3, handle_out: 3, handle_info: 2, code_change: 3, terminate: 2

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)
      @behaviour unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @phoenix_intercepts []
      @phoenix_log_join Keyword.get(opts, :log_join, :info)
      @phoenix_log_handle_in Keyword.get(opts, :log_handle_in, :debug)

      import unquote(__MODULE__)
      import Phoenix.Socket, only: [assign: 3]

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
      IO.write "#{Path.relative_to(env.file, File.cwd!)}:#{env.line}: [warning] " <>
               "An intercept for event \"#{event}\" has not yet been defined in #{env.module}.handle_out/3. " <>
               "Add \"#{event}\" to your list of intercepted events with intercept/1"
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
    :ok
  end

  @doc """
  Broadcast an event to all subscribers of the socket topic.

  The event's message must be a serializable map.

  ## Examples

      iex> broadcast(socket, "new_message", %{id: 1, content: "hello"})
      :ok

  """
  def broadcast(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast pubsub_server, topic, event, message
  end

  @doc """
  Same as `broadcast/3`, but raises if broadcast fails.
  """
  def broadcast!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast! pubsub_server, topic, event, message
  end

  @doc """
  Broadcast event from pid to all subscribers of the socket topic.

  The channel that owns the socket will not receive the published
  message. The event's message must be a serializable map.

  ## Examples

      iex> broadcast_from(socket, "new_message", %{id: 1, content: "hello"})
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} = assert_joined!(socket)
    Server.broadcast_from pubsub_server, channel_pid, topic, event, message
  end

  @doc """
  Same as `broadcast_from/3`, but raises if broadcast fails.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} = assert_joined!(socket)
    Server.broadcast_from! pubsub_server, channel_pid, topic, event, message
  end

  @doc """
  Sends event to the socket.

  The event's message must be a serializable map.

  ## Examples

      iex> push(socket, "new_message", %{id: 1, content: "hello"})
      :ok

  """
  def push(socket, event, message) do
    %{transport_pid: transport_pid, topic: topic} = assert_joined!(socket)
    Server.push(transport_pid, topic, event, message, socket.serializer)
  end

  @doc """
  Replies asynchronously to a socket push.

  Useful when you need to reply to a push that can't otherwise be handled using
  the `{:reply, {status, payload}, socket}` return from your `handle_in`
  callbacks. `reply/2` will be used in the rare cases you need to perform work in
  another process and reply when finished by generating a reference to the push
  with `socket_ref/1`.

  *Note*: In such cases, a `socket_ref` should be generated and
  passed to the external process, so the `socket` itself is not leaked outside
  the channel. The `socket` holds information such as assigns and transport
  configuration, so it's important to not copy this information outside of the
  channel that owns it.

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
  @spec socket_ref(Socket.t) :: socket_ref
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
