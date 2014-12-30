defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport
  alias Phoenix.Channel.Transport.InvalidReturn
  alias Phoenix.Transports.WebSocket
  alias Phoenix.Transports.LongPoller

  defmodule MyChannel do
    use Phoenix.Channel
    def join(socket, topic, msg) do
      send socket.pid, {:join, topic}
      msg
    end
    def leave(_socket, _msg) do
      Process.get(:leave)
    end
    def incoming(socket, "info", msg) do
      send socket.pid, :info
      msg
    end

    def incoming(socket, "some:event", _msg) do
      send socket.pid, {:incoming, socket.topic}
      socket
    end
    def incoming(_socket, "boom", msg), do: msg
    def incoming(socket, "put", dict) do
      Enum.reduce dict, socket, fn {k, v}, socket -> Socket.assign(socket, k, v) end
    end
    def incoming(socket, "get", %{"key" => key}) do
      send socket.pid, socket.assigns[key]
      socket
    end

    def outgoing(socket, "some:broadcast", _msg) do
      send socket.pid, :outgoing
      socket
    end
    def outgoing(socket, event, message) do
      reply(socket, event, message)
      socket
    end
  end

  defmodule Router do
    use Phoenix.Router, socket_mount: "/ws"

    channel "topic1:*", MyChannel
    channel "baretopic", MyChannel
    channel "wsonly:*", MyChannel, via: [WebSocket]
    channel "lponly:*", MyChannel, via: [LongPoller]
  end

  def new_socket do
    %Socket{pid: self,
            router: Router,
            topic: "topic1:subtopic",
            assigns: []}
  end
  def join_message(message) do
    %Message{topic: "topic1:subtopic",
             event: "join",
             payload: message}
  end

  test "#subscribe/unsubscribe's socket to/from topic" do
    socket = Socket.set_current_topic(new_socket, "top:subtop")

    assert Channel.subscribe(socket, "top:subtop")
    assert PubSub.subscribers("top:subtop") == [socket.pid]
    assert Channel.unsubscribe(socket, "top:subtop")
    assert PubSub.subscribers("top:subtop") == []
  end

  test "#broadcast broadcasts global message on topic" do
    PubSub.create("top:subtop")
    socket = Socket.set_current_topic(new_socket, "top:subtop")

    assert Channel.broadcast(socket, "event", %{foo: "bar"})
  end

  test "#broadcast raises friendly error when message arg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast("topic:subtopic", "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from broadcasts message on topic, skipping publisher" do
    PubSub.create("top:subtop")
    socket = new_socket
    |> Socket.set_current_topic("top:subtop")
    |> Channel.subscribe("top:subtop")

    assert Channel.broadcast_from(socket, "event", %{payload: "hello"})
    refute Enum.any?(Process.info(self)[:messages], &match?(%Message{}, &1))
  end

  test "#broadcast_from raises friendly error when message arg isn't a Map" do
    socket = Socket.set_current_topic(new_socket, "top:subtop")
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(socket, "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from/4 raises friendly error when message arg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(self, "topic:subtopic", "event", bar: "foo")
    end
  end

  test "#reply sends response to socket" do
    socket = Socket.set_current_topic(new_socket, "top:subtop")
    assert Channel.reply(socket, "event", %{payload: "hello"})

    assert Enum.any?(Process.info(self)[:messages], &match?({:socket_reply, %Message{}}, &1))
    assert_received {:socket_reply, %Message{
      topic: "top:subtop",
      event: "event",
      payload: %{payload: "hello"}
    }}
  end

  test "#reply raises friendly error when message arg isn't a Map" do
    socket = Socket.set_current_topic(new_socket, "top:subtop")
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.reply(socket, "event", foo: "bar", bar: "foo")
    end
  end

  test "Default #leave is generated as a noop" do
    socket = new_socket
    Process.put(:leave, socket)
    assert MyChannel.leave(socket, []) == socket
  end

  test "#leave can be overridden" do
    Process.put(:leave, :overridden)
    assert MyChannel.leave(new_socket, []) == :overridden
  end

  test "successful join authorizes and subscribes socket to topic" do
    message = join_message({:ok, new_socket})

    PubSub.create("topic1:subtopic")
    assert PubSub.subscribers("topic1:subtopic") == []
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    socket = HashDict.get(sockets, "topic1:subtopic")
    assert socket
    assert Socket.authorized?(socket, "topic1:subtopic")
    assert PubSub.subscribers("topic1:subtopic") == [socket.pid]
    assert PubSub.subscribers("topic1:subtopic") == [self]
  end

  test "unsuccessful join denies socket access to topic" do
    message = join_message({:error, new_socket, :unauthenticated})

    PubSub.create("topic1:subtopic")
    assert PubSub.subscribers("topic1:subtopic") == []
    {:error, sockets, :unauthenticated} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    refute HashDict.get(sockets, "topic1:subtopic")
    refute PubSub.subscribers("topic1:subtopic") == [self]
  end

  test "#leave is called when the socket conn closes, and is unsubscribed" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    Process.put(:leave, socket)
    Transport.dispatch_leave(sockets, :reason, WebSocket)
    assert PubSub.subscribers("topic1:subtopic") == []
  end

  test "#info is called when receiving regular process messages" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    Transport.dispatch_info(sockets, socket, WebSocket)
    assert_received :info
  end

  test "#join raise InvalidReturn exception when return type invalid" do
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", new_socket)
    message = join_message(:badreturn)

    assert_raise InvalidReturn, fn ->
      {:ok, _sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    end
  end

  test "#leave raise InvalidReturn exception when return type invalid" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    sock = HashDict.get(sockets, "topic1:subtopic")
    assert Socket.authorized?(sock, "topic1:subtopic")
    Process.put(:leave, :badreturn)
    assert_raise InvalidReturn, fn ->
      Transport.dispatch_leave(sockets, :reason, WebSocket)
    end
  end

  test "#event raises InvalidReturn exception when return type is invalid" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    sock = HashDict.get(sockets, "topic1:subtopic")
    assert Socket.authorized?(sock, "topic1:subtopic")
    message = %Message{topic: "topic1:subtopic",
                       event: "boom",
                       payload: :badreturn}

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, sockets, self, Router, WebSocket)
    end
  end

  test "returns heartbeat message when received, and does not store socket" do
    sockets = HashDict.new
    message = %Message{topic: "phoenix", event: "heartbeat", payload: %{}}

    assert {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    assert_received {:socket_reply, %Message{topic: "phoenix", event: "heartbeat", payload: %{}}}
    assert sockets == HashDict.new
  end

  test "socket state can change when receiving regular process messages" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    {:ok, sockets} = Transport.dispatch_info(sockets, Socket.assign(socket, :foo, :bar), WebSocket)
    socket = HashDict.get(sockets, "topic1:subtopic")

    assert socket.assigns[:foo] == :bar
  end

  test "Socket state can be put and retrieved" do
    socket = MyChannel.incoming(new_socket, "put", %{val: 123})
    _socket = MyChannel.incoming(socket, "get", %{"key" => :val})
    assert_received 123
  end

  test "outgoing/3 can be overidden for custom broadcast handling" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, "topic1:subtopic", socket)
    message = join_message({:ok, socket})

    PubSub.create("topic1:subtopic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, WebSocket)
    Transport.dispatch_broadcast(sockets, %Message{event: "some:broadcast",
                                                   topic: "topic1:subtopic",
                                                   payload: "hello"}, WebSocket)
    assert_received :outgoing
  end

  test "join/3 and incoming/3 match splat topics" do
    socket = new_socket |> Socket.set_current_topic("topic1:somesubtopic")
    message = %Message{topic: "topic1:somesubtopic",
                       event: "join",
                       payload: {:ok, socket}}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    assert_received {:join, "topic1:somesubtopic"}

    message = %Message{topic: "topic1",
                       event: "join",
                       payload: {:ok, socket}}
    {:error, _sockets, :bad_transport_match} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    refute_received {:join, "topic1"}

    message = %Message{topic: "topic1:somesubtopic",
                       event: "some:event",
                       payload: %{}}
    Transport.dispatch(message, sockets, self, Router, WebSocket)
    assert_received {:incoming, "topic1:somesubtopic"}

    message = %Message{topic: "topic1",
                       event: "some:event",
                       payload: %{}}
    Transport.dispatch(message, sockets, self, Router, WebSocket)
    refute_received {:incoming, "topic1:somesubtopic"}
  end

  test "join/3 and incoming/3 match bare topics" do
    socket = new_socket |> Socket.set_current_topic("baretopic")
    message = %Message{topic: "baretopic",
                       event: "join",
                       payload: {:ok, socket}}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    assert_received {:join, "baretopic"}

    message = %Message{topic: "baretopic:sub",
                       event: "join",
                       payload: {:ok, socket}}
    {:error, _sockets, :bad_transport_match} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    refute_received {:join, "baretopic:sub"}

    message = %Message{topic: "baretopic",
                       event: "some:event",
                       payload: %{}}
    Transport.dispatch(message, sockets, self, Router, WebSocket)
    assert_received {:incoming, "baretopic"}

    message = %Message{topic: "baretopic:sub",
                       event: "some:event",
                       payload: %{}}
    Transport.dispatch(message, sockets, self, Router, WebSocket)
    refute_received {:incoming, "baretopic:sub"}
  end

  test "channel `via:` option filters messages by transport" do
    # via WS
    socket = new_socket |> Socket.set_current_topic("wsonly:somesubtopic")
    message = %Message{topic: "wsonly:somesubtopic",
                       event: "join",
                       payload: {:ok, socket}}
    {:ok, _sockets} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    assert_received {:join, "wsonly:somesubtopic"}

    {:error, _sockets, :bad_transport_match} = Transport.dispatch(message, HashDict.new, self, Router, LongPoller)
    refute_received {:join, "wsonly:somesubtopic"}

    # via LP
    socket = new_socket |> Socket.set_current_topic("lponly:somesubtopic")
    message = %Message{topic: "lponly:somesubtopic",
                       event: "join",
                       payload: {:ok, socket}}
    {:ok, _sockets} = Transport.dispatch(message, HashDict.new, self, Router, LongPoller)
    assert_received {:join, "lponly:somesubtopic"}

    {:error, _sockets, :bad_transport_match} = Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    refute_received {:join, "lponly:somesubtopic"}
  end

  test "unmatched channel message returns {:error, sockets, :bad_transport_match}" do
    message = %Message{topic: "slfjskdjfsjfsklfj:somesubtopic", event: "join", payload: %{}}
    assert {:error, _sockets, :bad_transport_match} =
      Transport.dispatch(message, HashDict.new, self, Router, WebSocket)
    refute_received {:join, "slfjskdjfsjfsklfj:somesubtopic"}
  end
end
