defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport
  alias Phoenix.Channel.Transport.InvalidReturn

  defmodule MyChannel do
    use Phoenix.Channel
    def join(_socket, _topic, msg), do: msg
    def leave(_socket, _msg) do
      Process.get(:leave)
    end
    def event(socket, "info", msg) do
      send socket.pid, :info
      msg
    end
    def event(_socket, "boom", msg), do: msg
    def event(socket, "put", dict) do
      Enum.reduce dict, socket, fn {k, v}, socket -> Socket.assign(socket, k, v) end
    end
    def event(socket, "get", %{"key" => key}) do
      send socket.pid, socket.assigns[key]
      socket
    end
  end

  defmodule Router do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"

    channel "chan1", MyChannel
  end

  def new_socket do
    %Socket{pid: self,
            router: Router,
            topic: "topic",
            channel: "chan1",
            assigns: []}
  end
  def join_message(message) do
    %Message{channel: "chan1",
             topic: "topic",
             event: "join",
             message: message}
  end

  test "#subscribe/unsubscribe's socket to/from topic" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.subscribe(socket, "chan", "topic")
    assert PubSub.subscribers("chan:topic") == [socket.pid]
    assert Channel.unsubscribe(socket, "chan", "topic")
    assert PubSub.subscribers("chan:topic") == []
  end

  test "#broadcast broadcasts global message on channel" do
    PubSub.create("chan:topic")
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.broadcast(socket, "event", %{foo: "bar"})
  end

  test "#broadcast raises friendly error when message arg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast("channel", "topic", "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from broadcasts message on channel, skipping publisher" do
    PubSub.create("chan:topic")
    socket = new_socket
    |> Socket.set_current_channel("chan", "topic")
    |> Channel.subscribe("chan", "topic")

    assert Channel.broadcast_from(socket, "event", %{message: "hello"})
    refute Enum.any?(Process.info(self)[:messages], &match?(%Message{}, &1))
  end

  test "#broadcast_from raises friendly error when message arg isn't a Map" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(socket, "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from/5 raises friendly error when message arg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(self, "channel", "topic", "event", bar: "foo")
    end
  end

  test "#reply sends response to socket" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")
    assert Channel.reply(socket, "event", %{message: "hello"})

    assert Enum.any?(Process.info(self)[:messages], &match?(%Message{}, &1))
    assert_received %Message{
      channel: "chan",
      event: "event",
      message: %{message: "hello"}, topic: "topic"
    }
  end

  test "#reply raises friendly error when message arg isn't a Map" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")
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

  test "successful join authorizes and subscribes socket to channel/topic" do
    message = join_message({:ok, new_socket})

    PubSub.create("chan1:topic")
    assert PubSub.subscribers("chan1:topic") == []
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router)
    socket = HashDict.get(sockets, {"chan1", "topic"})
    assert socket
    assert Socket.authorized?(socket, "chan1", "topic")
    assert PubSub.subscribers("chan1:topic") == [socket.pid]
    assert PubSub.subscribers("chan1:topic") == [self]
  end

  test "unsuccessful join denies socket access to channel/topic" do
    message = join_message({:error, new_socket, :unauthenticated})

    PubSub.create("chan1:topic")
    assert PubSub.subscribers("chan1:topic") == []
    {:error, sockets, :unauthenticated} = Transport.dispatch(message, HashDict.new, self, Router)
    refute HashDict.get(sockets, {"chan1", "topic"})
    refute PubSub.subscribers("chan1:topic") == [self]
  end

  test "#leave is called when the socket conn closes, and is unsubscribed" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = join_message({:ok, socket})

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    Process.put(:leave, socket)
    Transport.dispatch_leave(sockets, :reason)
    assert PubSub.subscribers("chan1:topic") == []
  end

  test "#info is called when receiving regular process messages" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = join_message({:ok, socket})

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    Transport.dispatch_info(sockets, socket)
    assert_received :info
  end

  test "#join raise InvalidReturn exception when return type invalid" do
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, new_socket)
    message = join_message(:badreturn)

    assert_raise InvalidReturn, fn ->
      {:ok, _sockets} = Transport.dispatch(message, sockets, self, Router)
    end
  end

  test "#leave raise InvalidReturn exception when return type invalid" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = join_message({:ok, socket})

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    sock = HashDict.get(sockets, {"chan1", "topic"})
    assert Socket.authorized?(sock, "chan1", "topic")
    Process.put(:leave, :badreturn)
    assert_raise InvalidReturn, fn ->
      Transport.dispatch_leave(sockets, :reason)
    end
  end

  test "#event raises InvalidReturn exception when return type is invalid" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = join_message({:ok, socket})

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    sock = HashDict.get(sockets, {"chan1", "topic"})
    assert Socket.authorized?(sock, "chan1", "topic")
    message = %Message{channel: "chan1",
                       topic: "topic",
                       event: "boom",
                       message: :badreturn}

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, sockets, self, Router)
    end
  end

  test "phoenix channel returns heartbeat message when received" do
    sockets = HashDict.put(HashDict.new, {"phoenix", "conn"}, new_socket)
    message = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}

    assert match?({:ok, _sockets}, Transport.dispatch(message, sockets, self, Router))
    assert_received %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
  end

  test "socket state can change when receiving regular process messages" do
    socket = new_socket
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = join_message({:ok, socket})

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    {:ok, sockets} = Transport.dispatch_info(sockets, Socket.assign(socket, :foo, :bar))
    socket = HashDict.get(sockets, {"chan1", "topic"})

    assert socket.assigns[:foo] == :bar
  end

  test "Socket state can be put and retrieved" do
    socket = MyChannel.event(new_socket, "put", %{val: 123})
    _socket = MyChannel.event(socket, "get", %{"key" => :val})
    assert_received 123
  end
end
