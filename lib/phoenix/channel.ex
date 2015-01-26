defmodule Phoenix.Channel do

  @moduledoc """
  Defines a Phoenix Channel.

  Channels provide a means for bidirectional communication from clients that
  integrates with the `Phoenix.PubSub` layer for soft-realtime functionality.

  ## Topics & Callbacks
  When clients join a channel, they do so by subscribing a topic.
  Topics are string idenitifiers in the `Phoenix.PubSub` layer that allow
  multiple processes to subscribe and broadcast messages about a give topic.
  Everytime you join a Channel, you need to choose which particular topic you
  want to listen to. The topic is just an identifier, but by convention it is
  often made of two parts: `"topic:subtopic"`. Using the `"topic:subtopic"`
  approach pairs nicely with the `Phoenix.Router.channel/3` macro to match
  topic patterns in your router to your channel handlers:

      socket "/ws", MyApp do
        channel "rooms:*", RoomChannel
      end

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

  To authorize a socket in `join/3`, return `{:ok, socket}`
  To refuse authorization in `join/3, return `:ignore`


  ### Incoming Events
  After a client has successfully joined a channel, incoming events from the
  client are routed through the channel's `handle_in/3` callbacks. Within these
  callbacks, you can perform any action. Typically you'll either foward a
  message out to all listeners with `Phoenix.Channel.broadcast/3`, or reply
  directly to the socket with `Phoenix.Channel.reply/3`.
  Incoming callbacks must return the `socket` to maintain ephemeral state.

  Here's an example of receiving an incoming `"new:msg"` event from a one client,
  and broadcasting the message to all topic subscribers for this socket.

      def handle_in("new:msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast socket, "new:msg", %{uid: uid, body: body}
        {:ok, socket}
      end

  You can also send a reply directly to the socket:

      # client asks for their current rank, reply sent directly as new event
      def handle_in("current:rank", socket) do
        reply socket, "current:rank", %{val: Game.get_rank(socket.assigns[:user])}
        {:ok, socket}
      end


  ### Outgoing Events

  When an event is broadcasted with `Phoenix.Channel.broadcast/3`, each channel
  subscribers' `handle_out/3` callback is triggered where the event can be
  relayed as is, or customized on a socket by socket basis to append extra
  information, or conditionally filter the message from being delivered.
  *Note*: `broadcast/3` and `reply/3` both return `{:ok, socket}`.

      def handle_in("new:msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast socket, "new:msg", %{uid: uid, body: body}
      end

      # for every socket subscribing on this topic, append an `is_editable`
      # value for client metadata
      def handle_out("new:msg", msg, socket) do
        reply socket, "new:msg", Dict.merge(msg,
          is_editable: User.can_edit_message?(socket.assigns[:user], msg)
        )
      end

      # do not send broadcasted `"user:joined"` events if this socket's user
      # is ignoring the user who joined
      def handle_out("user:joined", msg, socket) do
        if User.ignoring?(socket.assigns[:user], msg.user_id) do
          {:ok, socket}
        else
          reply socket, "user:joined", msg
        end
      end

   By default, unhandled outgoing events are forwarded to each client as a reply,
   but you'll need to define the catch-all clause yourself once you define an
   `handle_out/3` clause.

  """

  use Behaviour
  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.Message

  defcallback join(topic :: binary, auth_msg :: map, Socket.t) :: {:ok, Socket.t} |
                                                                  :ignore |
                                                                  {:error, reason :: term, Socket.t}

  defcallback leave(msg :: map, Socket.t) :: {:ok, Socket.t}

  defcallback handle_in(event :: String.t, msg :: map, Socket.t) :: {:ok, Socket.t} |
                                                                    {:leave, Socket.t} |
                                                                    {:error, reason :: term, Socket.t}

  defcallback handle_out(event :: String.t, msg :: map, Socket.t) :: {:ok, Socket.t} |
                                                                     {:leave, Socket.t} |
                                                                     {:error, reason :: term, Socket.t}

  defmacro __using__(options \\ []) do
    quote do
      options = unquote(options)
      @behaviour unquote(__MODULE__)
      @pubsub_server options[:pubsub_server] ||
        Phoenix.Naming.module_to_pub_server(__MODULE__)


      import unquote(__MODULE__), only: [reply: 3]
      import Phoenix.Socket

      def pubsub_server, do: @pubsub_server

      def leave(message, socket), do: {:ok, socket}

      def handle_out(event, message, socket) do
        reply(socket, event, message)
      end

      def broadcast_from(socket = %Socket{}, event, msg) do
        Phoenix.Channel.broadcast_from(@pubsub_server, socket, event, msg)
      end
      def broadcast_from(from, topic, event, msg) when is_map(msg) do
        Phoenix.Channel.broadcast_from(@pubsub_server, from, topic, event, msg)
      end

      def broadcast(topic_or_socket, event, msg) do
        Phoenix.Channel.broadcast(@pubsub_server, topic_or_socket, event, msg)
      end

      defoverridable leave: 2, handle_out: 3
    end
  end

  @doc """
  Broadcast event, serializable as JSON to channel

  ## Examples

      iex> Channel.broadcast "rooms:global", "new:message", %{id: 1, content: "hello"}
      :ok
      iex> Channel.broadcast socket, "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast(server, topic, event, message) when is_binary(topic) do
    broadcast_from server, :none, topic, event, message
  end

  def broadcast(server, socket = %Socket{}, event, message) do
    broadcast_from server, :none, socket.topic, event, message
    {:ok, socket}
  end

  @doc """
  Broadcast event from pid, serializable as JSON to channel
  The broadcasting socket `from`, does not receive the published message.
  The event's message must be a map serializable as JSON.

  ## Examples

      iex> Channel.broadcast_from self, "rooms:global", "new:message", %{id: 1, content: "hello"}
      :ok

  """
  def broadcast_from(pubsub_server, socket = %Socket{}, event, message) do
    broadcast_from(pubsub_server, socket.pid, socket.topic, event, message)
    {:ok, socket}
  end
  def broadcast_from(pubsub_server, from, topic, event, message) when is_map(message) do
    PubSub.broadcast_from pubsub_server, from, topic, {:socket_broadcast, %Message{
      topic: topic,
      event: event,
      payload: message
    }}
  end
  def broadcast_from(_, _, _, _, _), do: raise_invalid_message

  @doc """
  Sends Dict, JSON serializable message to socket
  """
  def reply(socket, event, message) when is_map(message) do
    send socket.pid, {:socket_reply, %Message{
      topic: socket.topic,
      event: event,
      payload: message
    }}
    {:ok, socket}
  end
  def reply(_, _, _), do: raise_invalid_message

  defp raise_invalid_message, do: raise "Message argument must be a map"
end
