defmodule Phoenix.Channel do
  @moduledoc """
  Defines a Phoenix Channel.

  Channels provide a means for bidirectional communication from clients that
  integrate with the `Phoenix.PubSub` layer for soft-realtime functionality.

  ## Topics & Callbacks

  When clients join a channel, they do so by subscribing to a topic.
  Topics are string identifiers in the `Phoenix.PubSub` layer that allow
  multiple processes to subscribe and broadcast messages about a given topic.
  Everytime you join a Channel, you need to choose which particular topic you
  want to listen to. The topic is just an identifier, but by convention it is
  often made of two parts: `"topic:subtopic"`. Using the `"topic:subtopic"`
  approach pairs nicely with the `Phoenix.Socket.channel/2` macro to match
  topic patterns in your router to your channel handlers:

      channel "rooms:*", MyApp.RoomChannel

  Any topic coming into the router with the `"rooms:"` prefix, would dispatch
  to `MyApp.RoomChannel` in the above example. Topics can also be pattern
  matched in your channels' `join/3` callback to pluck out the scoped pattern:

      # handles the special `"lobby"` subtopic
      def join("rooms:lobby", _auth_message, socket) do
        {:ok, socket}
      end

      # handles any other subtopic as the room ID, ie `"rooms:12"`, `"rooms:34"`
      def join("rooms:" <> room_id, auth_message, socket) do
        {:ok, socket}
      end

  ### Authorization

  Clients must join a channel to send and receive PubSub events on that channel.
  Your channels must implement a `join/3` callback that authorizes the socket
  for the given topic. It is common for clients to send up authorization data,
  such as HMAC'd tokens for this purpose.

  To authorize a socket in `join/3`, return `{:ok, socket}`.
  To refuse authorization in `join/3`, return `{:error, reply}`.

  ### Incoming Events

  After a client has successfully joined a channel, incoming events from the
  client are routed through the channel's `handle_in/3` callbacks. Within these
  callbacks, you can perform any action. Typically you'll either forward a
  message to all listeners with `Phoenix.Channel.broadcast!/3`, or push a message
  directly down the socket with `Phoenix.Channel.push/3`.
  Incoming callbacks must return the `socket` to maintain ephemeral state.

  Here's an example of receiving an incoming `"new_msg"` event from one client,
  and broadcasting the message to all topic subscribers for this socket.

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast! socket, "new_msg", %{uid: uid, body: body}
        {:noreply, socket}
      end

  You can also push a message directly down the socket:

      # client asks for their current rank, push sent directly as a new event.
      def handle_in("current:rank", socket) do
        push socket, "current:rank", %{val: Game.get_rank(socket.assigns[:user])}
        {:noreply, socket}
      end

  ### Replies

  In addition to pushing messages out when you receive a `handle_in` event,
  you can also reply directly to a client event for request/response style
  messaging. This is useful when a client must know the result of an operation
  or to simply ack messages.

  For example, imagine creating a resource and replying with the created record:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          Repo.insert!(changeset)
          {:reply, {:ok, changeset}, socket}
        else
          {:reply, {:error, changeset.errors}, socket}
        end
      end

  Alternatively, you may just want to ack the status of the operation:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          Repo.insert!(changeset)
          {:ok, socket}
        else
          {:reply, :error, socket}
        end
      end

  ### Outgoing Events

  When an event is broadcasted with `Phoenix.Channel.broadcast/3`, each channel
  subscriber's `handle_out/3` callback is triggered where the event can be
  relayed as is, or customized on a socket by socket basis to append extra
  information, or conditionally filter the message from being delivered.

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast! socket, "new_msg", %{uid: uid, body: body}
        {:noreply, socket}
      end

      # for every socket subscribing to this topic, append an `is_editable`
      # value for client metadata.
      def handle_out("new_msg", msg, socket) do
        push socket, "new_msg", Map.merge(msg,
          is_editable: User.can_edit_message?(socket.assigns[:user], msg)
        )
        {:noreply, socket}
      end

      # do not send broadcasted `"user:joined"` events if this socket's user
      # is ignoring the user who joined.
      def handle_out("user:joined", msg, socket) do
        unless User.ignoring?(socket.assigns[:user], msg.user_id) do
          push socket, "user:joined", msg
        end
        {:noreply, socket}
      end

  By default, unhandled outgoing events are forwarded to each client as a push,
  but you'll need to define the catch-all clause yourself once you define an
  `handle_out/3` clause.

  ## Broadcasting to an external topic

  In some cases, you will want to broadcast messages without the context of a `socket`.
  This could be for broadcasting from within your channel to an external topic, or
  broadcasting from elsewhere in your application like a Controller or GenServer.
  For these cases, you can broadcast from your Endpoint. Its configured PubSub
  server will be used:

      # within channel
      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        ...
        broadcast_from! socket, "new_msg", %{uid: uid, body: body}
        MyApp.Endpoint.broadcast_from! self(), "rooms:superadmin", "new_msg", %{uid: uid, body: body}
        {:noreply, socket}
      end

      # within controller
      def create(conn, params) do
        ...
        MyApp.Endpoint.broadcast! "rooms:" <> rid, "new_msg", %{uid: uid, body: body}
        MyApp.Endpoint.broadcast! "rooms:superadmin", "new_msg", %{uid: uid, body: body}
        redirect conn, to: "/"
      end

  ## Terminate

  On termination, the channel callback `terminate/2` will be invoked with
  the error reason and the socket.

  If we are terminating because the client left, the reason will be
  `{:shutdown, :left}`. Similarly, if we are terminating because the
  client connection was closed, the reason will be `{:shutdown, :closed}`.

  If any of the callbacks return a stop tuple, that will also trigger
  terminate, with the given reason.

  Note `terminate/2` may also be invoked in case of errors or exits
  but only if the current process is trapping exits. This practice,
  however, is typically not recommended.
  """

  use Behaviour
  alias Phoenix.Socket
  alias Phoenix.Channel.Server

  @type reply :: status :: atom | {status :: atom, response :: map}

  defcallback join(topic :: binary, auth_msg :: map, Socket.t) ::
              {:ok, Socket.t} |
              {:ok, map, Socket.t} |
              {:error, map}

  defcallback handle_in(event :: String.t, msg :: map, Socket.t) ::
              {:noreply, Socket.t} |
              {:reply, reply, Socket.t} |
              {:stop, reason :: term, Socket.t} |
              {:stop, reason :: term, reply, Socket.t}

  defcallback handle_info(term, Socket.t) ::
              {:noreply, Socket.t} |
              {:stop, reason :: term, Socket.t}

  defcallback terminate(msg :: map, Socket.t) ::
              {:shutdown, :left | :closed} |
              term

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__)
      import Phoenix.Socket, only: [assign: 3]
      Module.register_attribute(__MODULE__, :phoenix_handle_outs, accumulate: true)

      def handle_in(_event, _message, socket) do
        {:noreply, socket}
      end

      def handle_info(_message, socket), do: {:noreply, socket}

      def terminate(_reason, _socket), do: :ok

      defoverridable handle_info: 2, handle_in: 3, terminate: 2
    end
  end

  defmacro __before_compile__(_) do
    quote do
      if @phoenix_handle_outs != [] do
        def __fastlane__?(event) when event in @phoenix_handle_outs, do: false
      end
      def __fastlane__?(event), do: true
    end
  end

  def __on_definition__(env, :def, :handle_out, [event, _payload, _socket], _, _)
    when is_binary(event) do
    Module.put_attribute(env.module, :phoenix_handle_outs, event)
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
  end

  @doc """
  Broadcast an event to all subscribers of the socket topic.

  The event's message must be a serializable map.

  ## Examples

      iex> broadcast socket, "new_message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast pubsub_server, topic, event, message
  end

  @doc """
  Same as `broadcast/3` but raises if broadcast fails.
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

      iex> broadcast_from socket, "new_message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} = assert_joined!(socket)
    Server.broadcast_from pubsub_server, channel_pid, topic, event, message
  end

  @doc """
  Same as `broadcast_from/3` but raises if broadcast fails.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} = assert_joined!(socket)
    Server.broadcast_from! pubsub_server, channel_pid, topic, event, message
  end

  @doc """
  Sends event to the socket.

  The event's message must be a serializable map.

  ## Examples

      iex> push socket, "new_message", %{id: 1, content: "hello"}
      :ok

  """
  def push(socket, event, message) do
    %{transport_pid: transport_pid, topic: topic} = assert_joined!(socket)
    Server.push(transport_pid, topic, event, message, socket.serializer)
  end

  defp assert_joined!(%Socket{joined: true} = socket) do
    socket
  end

  defp assert_joined!(%Socket{joined: false}) do
    raise """
    `push` and `broadcast` can only be called after the socket has finished joining.
    To push a message on join, send to self and handle in handle_info/2, ie:

        def join(topic, auth_msg, socket) do
          ...
          send(self, :after_join)
          {:ok, socket}
        end

        def handle_info(:after_join, socket) do
          push socket, "feed", %{list: feed_items(socket)}
          {:noreply, socket}
        end
    """
  end
end
