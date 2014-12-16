defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case, async: true
  alias Phoenix.PubSub
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport
  alias Phoenix.Channel.Transport.InvalidReturn

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channel: "somechan",
            assigns: []}
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

  defmodule AuthenticatedChannel do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:ok, socket}
    def leave(socket, _msg) do
      send(socket.pid, :left)
      socket
    end
    def event(socket, "info", _msg) do
      send(socket.pid, :info)
      socket
    end
  end

  defmodule UnauthenticatedChannel do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:error, socket, :unauthenticated}
    def leave(socket, _msg), do: :overridden
  end

  defmodule BadReturnJoinChannel do
    use Phoenix.Channel
    def join(_socket, _topic, _msg), do: :some_bad_return
  end

  defmodule BadReturnLeaveChannel do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:ok, socket}
    def leave(_socket, _msg), do: :some_bad_return
  end

  defmodule BadReturnArgsChannel do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:ok, socket}
    def event(_socket, "boom", _msg), do: :some_bad_return
  end

  defmodule ChangeSocketStateChannel do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:ok, socket}
    def event(socket, "info", _msg) do
      Socket.assign(socket, :foo, :bar)
    end
    def event(socket, "put", dict) do
      Enum.reduce dict, socket, fn {k, v}, socket -> Socket.assign(socket, k, v) end
    end
    def event(socket, "get", %{"key" => key}) do
      send socket.pid, socket.assigns[key]
      socket
    end
  end

  defmodule ErrorChannel do
    use Phoenix.Channel
    def join(_socket, _topic, _msg), do: raise "Foo"
  end

  defmodule Router do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"

    channel "chan1", AuthenticatedChannel
    channel "chan2", UnauthenticatedChannel
    channel "chan3", BadReturnJoinChannel
    channel "chan4", BadReturnLeaveChannel
    channel "chan5", BadReturnArgsChannel
    channel "chan6", ChangeSocketStateChannel
    channel "chan7", ErrorChannel
  end

  test "Default #leave is generated as a noop" do
    socket = new_socket
    assert AuthenticatedChannel.leave(socket, []) == socket
  end

  test "#leave can be overridden" do
    assert UnauthenticatedChannel.leave(new_socket, []) == :overridden
  end

  test "successful join authorizes and subscribes socket to channel/topic" do
    message = %Message{channel: "chan1", topic: "topic", event: "join", message: %{}}

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
    message = %Message{channel: "chan2", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan2:topic")
    assert PubSub.subscribers("chan2:topic") == []
    {:error, sockets, :unauthenticated} = Transport.dispatch(message, HashDict.new, self, Router)
    refute HashDict.get(sockets, {"chan2", "topic"})
    refute PubSub.subscribers("chan2:topic") == [self]
  end

  test "#leave is called when the socket conn closes, and is unsubscribed" do
    socket = %Socket{pid: self, router: Router, channel: "chan1"}
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = %Message{channel: "chan1", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    Transport.dispatch_leave(sockets, :reason)
    assert_received :left
    assert PubSub.subscribers("chan1:topic") == []
  end

  test "#info is called when receiving regular process messages" do
    socket = %Socket{pid: self, router: Router, channel: "chan1"}
    sockets = HashDict.put(HashDict.new, {"chan1", "topic"}, socket)
    message = %Message{channel: "chan1", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan1:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    Transport.dispatch_info(sockets, :stuff)
    assert_received :info
  end

  test "#join raise InvalidReturn exception when return type invalid" do
    socket = %Socket{pid: self, router: Router, channel: "chan3"}
    sockets = HashDict.put(HashDict.new, {"chan3", "topic"}, socket)
    message = %Message{channel: "chan3", topic: "topic", event: "join", message: %{}}

    assert_raise InvalidReturn, fn ->
      {:ok, _sockets} = Transport.dispatch(message, sockets, self, Router)
    end
  end

  test "#leave raise InvalidReturn exception when return type invalid" do
    socket = %Socket{pid: self, router: Router, channel: "chan4", topic: "topic"}
    sockets = HashDict.put(HashDict.new, {"chan4", "topic"}, socket)
    message = %Message{channel: "chan4", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan4:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    sock = HashDict.get(sockets, {"chan4", "topic"})
    assert Socket.authorized?(sock, "chan4", "topic")
    assert_raise InvalidReturn, fn ->
      Transport.dispatch_leave(sockets, :reason)
    end
  end

  test "#event raises InvalidReturn exception when return type is invalid" do
    socket = %Socket{pid: self, router: Router, channel: "chan5", topic: "topic"}
    sockets = HashDict.put(HashDict.new, {"chan5", "topic"}, socket)
    message = %Message{channel: "chan5", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan5:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    sock = HashDict.get(sockets, {"chan5", "topic"})
    assert Socket.authorized?(sock, "chan5", "topic")
    message = %Message{channel: "chan5", topic: "topic", event: "boom", message: %{}}

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, sockets, self, Router)
    end
  end

  test "phoenix channel returns heartbeat message when received" do
    socket = %Socket{pid: self, router: Router9, channel: "phoenix"}
    sockets = HashDict.put(HashDict.new, {"phoenix", "conn"}, socket)
    message = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}

    assert match?({:ok, _sockets}, Transport.dispatch(message, sockets, self, Router9))
    assert_received %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
  end

  test "socket state can change when receiving regular process messages" do
    socket = %Socket{pid: self, router: Router, channel: "chan6", topic: "topic"}
    sockets = HashDict.put(HashDict.new, {"chan6", "topic"}, socket)
    message = %Message{channel: "chan6", topic: "topic", event: "join", message: %{}}

    PubSub.create("chan6:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router)
    {:ok, sockets} = Transport.dispatch_info(sockets, :stuff)
    socket = HashDict.get(sockets, {"chan6", "topic"})

    assert socket.assigns[:foo] == :bar
  end

  test "Socket state can be put and retrieved" do
    socket = %Socket{pid: self, router: Router, channel: "chan66"}
    socket = ChangeSocketStateChannel.event(socket, "put", %{val: 123})
    _socket = ChangeSocketStateChannel.event(socket, "get", %{"key" => :val})
    assert_received 123
  end
end
