defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case
  alias Phoenix.Topic
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
    assert Topic.subscribers("chan:topic") == [socket.pid]
    assert Channel.unsubscribe(socket, "chan", "topic")
    assert Topic.subscribers("chan:topic") == []
  end

  test "#broadcast broadcasts global message on channel" do
    Topic.create("chan:topic")
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
    Topic.create("chan:topic")
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
    defmodule Chan1 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
    end
    socket = new_socket
    assert Chan1.leave(socket, []) == socket
  end

  test "#leave can be overridden" do
    defmodule Chan2 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
      def leave(_socket, _msg), do: :overridden
    end

    assert Chan2.leave(new_socket, []) == :overridden
  end

  test "successful join authorizes and subscribes socket to channel/topic" do
    defmodule Chan3 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
    end
    defmodule Router3 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan3", Chan3
    end

    message = %Message{channel: "chan3", topic: "topic", event: "join", message: %{}}

    Topic.create("chan3:topic")
    assert Topic.subscribers("chan3:topic") == []
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router3)
    socket = HashDict.get(sockets, {"chan3", "topic"})
    assert socket
    assert Socket.authorized?(socket, "chan3", "topic")
    assert Topic.subscribers("chan3:topic") == [socket.pid]
    assert Topic.subscribers("chan3:topic") == [self]
  end

  test "unsuccessful join denies socket access to channel/topic" do
    defmodule Chan4 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:error, socket, :unauthorized}
    end
    defmodule Router4 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan4", Chan4
    end

    message = %Message{channel: "chan4", topic: "topic", event: "join", message: %{}}

    Topic.create("chan4:topic")
    assert Topic.subscribers("chan4:topic") == []
    {:error, sockets, :unauthorized} = Transport.dispatch(message, HashDict.new, self, Router4)
    refute HashDict.get(sockets, {"chan4", "topic"})
    refute Topic.subscribers("chan4:topic") == [self]
  end

  test "#leave is called when the socket conn closes, and is unsubscribed" do
    defmodule Chan5 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
      def leave(socket, _msg) do
        send(socket.pid, :left)
        socket
      end
    end
    defmodule Router5 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan5", Chan5
    end

    socket = %Socket{pid: self, router: Router5, channel: "chan5"}
    sockets = HashDict.put(HashDict.new, {"chan5", "topic"}, socket)
    message = %Message{channel: "chan5", topic: "topic", event: "join", message: %{}}

    Topic.create("chan5:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router5)
    Transport.dispatch_leave(sockets, :reason)
    assert_received :left
    assert Topic.subscribers("chan5:topic") == []
  end

  test "#info is called when receiving regular process messages" do
    defmodule Chan6 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
      def event(socket, "info", _msg) do
        send(socket.pid, :info)
        socket
      end
    end
    defmodule Router6 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan6", Chan6
    end

    socket = %Socket{pid: self, router: Router6, channel: "chan6"}
    sockets = HashDict.put(HashDict.new, {"chan6", "topic"}, socket)
    message = %Message{channel: "chan6", topic: "topic", event: "join", message: %{}}

    Topic.create("chan6:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router6)
    Transport.dispatch_info(sockets, :stuff)
    assert_received :info
  end

  test "#join raise InvalidReturn exception when return type invalid" do
    defmodule Chan7 do
      use Phoenix.Channel
      def join(_socket, _topic, _msg), do: :some_bad_return
    end
    defmodule Router7 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan7", Chan7
    end

    socket = %Socket{pid: self, router: Router7, channel: "chan7"}
    sockets = HashDict.put(HashDict.new, {"chan7", "topic"}, socket)
    message = %Message{channel: "chan7", topic: "topic", event: "join", message: %{}}

    assert_raise InvalidReturn, fn ->
      {:ok, _sockets} = Transport.dispatch(message, sockets, self, Router7)
    end
  end

  test "#leave raise InvalidReturn exception when return type invalid" do
    defmodule Chan8 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
      def leave(_socket, _msg), do: :some_bad_return
    end
    defmodule Router8 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan8", Chan8
    end

    socket = %Socket{pid: self, router: Router8, channel: "chan8"}
    sockets = HashDict.put(HashDict.new, {"chan8", "topic"}, socket)
    message = %Message{channel: "chan8", topic: "topic", event: "join", message: %{}}

    Topic.create("chan6:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router8)

    assert_raise InvalidReturn, fn ->
      Transport.dispatch_leave(sockets, :reason)
    end
  end

  test "#event raises InvalidReturn exception when return type is invalid" do
    defmodule Chan9 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:ok, socket}
      def event(_socket, "boom", _msg), do: :some_bad_return
    end
    defmodule Router9 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan9", Chan9
    end

    socket = %Socket{pid: self, router: Router9, channel: "chan9", topic: "topic"}
    sockets = HashDict.put(HashDict.new, {"chan9", "topic"}, socket)
    message = %Message{channel: "chan9", topic: "topic", event: "join", message: %{}}

    Topic.create("chan9:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router9)
    sock = HashDict.get(sockets, {"chan9", "topic"})
    assert Socket.authorized?(sock, "chan9", "topic")
    message = %Message{channel: "chan9", topic: "topic", event: "boom", message: %{}}

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, sockets, self, Router9)
    end
  end

  test "phoenix channel returns heartbeat message when received" do
    socket = %Socket{pid: self, router: Router9, channel: "phoenix"}
    sockets = HashDict.put(HashDict.new, {"phoenix", "conn"}, socket)
    message = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}

    assert match?({:ok, _sockets}, Transport.dispatch(message, sockets, self, Router9))
    assert_received %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
  end

  defmodule Chan10 do
    use Phoenix.Channel
    def join(socket, _topic, _msg), do: {:ok, socket}
    def event(socket, "info", _msg) do
      assign(socket, :foo, :bar)
    end
    def event(socket, "put", dict) do
      Enum.reduce dict, socket, fn {k, v}, socket -> assign(socket, k, v) end
    end
    def event(socket, "get", %{"key" => key}) do
      send socket.pid, get_assign(socket, key)
      socket
    end
  end
  defmodule Router10 do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"
    channel "chan10", Chan10
  end

  test "socket state can change when receiving regular process messages" do

    socket = %Socket{pid: self, router: Router10, channel: "chan10", topic: "topic"}
    sockets = HashDict.put(HashDict.new, {"chan10", "topic"}, socket)
    message = %Message{channel: "chan10", topic: "topic", event: "join", message: %{}}

    Topic.create("chan10:topic")
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router10)
    {:ok, sockets} = Transport.dispatch_info(sockets, :stuff)
    socket = HashDict.get(sockets, {"chan10", "topic"})

    assert Socket.get_assign(socket, :foo) == :bar
  end

  test "Socket state can be put and retrieved" do
    socket = %Socket{pid: self, router: Router10, channel: "chan10", topic: "topic"}
    socket = Chan10.event(socket, "put", %{val: 123})
    _socket = Chan10.event(socket, "get", %{"key" => :val})
    assert_received 123
  end
end
