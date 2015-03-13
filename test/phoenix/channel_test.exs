defmodule Phoenix.ChannelTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel.Transport
  alias Phoenix.Channel.Transport.InvalidReturn
  alias Phoenix.Transports.WebSocket
  alias Phoenix.Transports.LongPoller

  defmodule BlankChannel do
    use Phoenix.Channel
    def join(_topic, _msg, socket), do: {:ok, socket}

    def handle_in(_event, _msg, socket) do
      {:ok, socket}
    end
  end

  defmodule MyChannel do
    use Phoenix.Channel
    def join(topic, msg, socket) do
      send socket.pid, {:join, topic}
      msg.(socket)
    end

    def leave(%{return: msg}, socket) do
      send socket.pid, :leave_triggered
      msg
    end
    def leave(%{reason: %{return: msg}}, socket) do
      send socket.pid, :leave_triggered
      msg
    end
    def leave(_msg, socket) do
      send socket.pid, :leave_triggered
      {:ok, socket}
    end

    def handle_in("some:event", _msg, socket) do
      send socket.pid, {:handle_in, socket.topic}
      {:ok, socket}
    end
    def handle_in("boom", msg, socket), do: msg.(socket)
    def handle_in("put", dict, socket) do
      {:ok, Enum.reduce(dict, socket, fn {k, v}, sock -> Socket.assign(sock, k, v) end)}
    end
    def handle_in("get", %{"key" => key}, socket) do
      send socket.pid, socket.assigns[key]
      {:ok, socket}
    end
    def handle_in("should:be:going", _msg, socket) do
      {:leave, socket}
    end

    def handle_out("some:broadcast", _msg, socket) do
      send socket.pid, :handle_out
      {:ok, socket}
    end
    def handle_out("everyone:leave", _msg, socket) do
      send socket.pid, :everyone_leaving
      {:leave, socket}
    end
    def handle_out(event, message, socket) do
      reply(socket, event, message)
    end

    def handle_info("should:arrive", socket) do
      send socket.pid, :handle_info_triggered
      {:ok, socket}
    end
  end

  defmodule Router do
    use Phoenix.Router

    socket "/ws" do
      channel "topic1:*", MyChannel
      channel "baretopic", MyChannel
      channel "wsonly:*", MyChannel, via: [WebSocket]
      channel "lponly:*", MyChannel, via: [LongPoller]
    end

    socket "/ws2", Phoenix.ChannelTest, via: [WebSocket] do
      channel "topic2:*", Elixir.MyChannel
      channel "topic2-override:*", Elixir.MyChannel, via: [LongPoller]
    end

    socket "/ws3", alias: Phoenix.ChannelTest do
      channel "topic3:*", Elixir.MyChannel
    end
  end

  def new_socket do
    %Socket{pid: self,
            router: Router,
            topic: "topic1:subtopic",
            assigns: []}
  end

  def join_message(func) do
    %Message{topic: "topic1:subtopic",
             event: "join",
             payload: func}
  end

  def subscribers(server, topic) do
    PubSub.Local.subscribers(Module.concat(server, Local), topic)
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "#subscribe/unsubscribe's socket to/from topic" do
    socket = Socket.put_topic(new_socket, "top:subtop")

    assert PubSub.subscribe(:phx_pub, socket.pid, "top:subtop")
    assert subscribers(:phx_pub, "top:subtop") == [socket.pid]
    assert PubSub.unsubscribe(:phx_pub, socket.pid, "top:subtop")
    assert subscribers(:phx_pub, "top:subtop") == []
  end

  test "#broadcast and #broadcast! broadcasts global message on topic" do
    socket = Socket.put_topic(new_socket, "top:subtop")

    assert Channel.broadcast(:phx_pub, socket, "event", %{foo: "bar"})
    assert Channel.broadcast!(:phx_pub, socket, "event", %{foo: "bar"})
  end


  test "#broadcast and #broadcast! raises friendly error when message arg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast(:phx_pub, "topic:subtopic", "event", bar: "foo", foo: "bar")
    end
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast!(:phx_pub, "topic:subtopic", "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from and #broadcast_from! broadcasts message, skipping publisher" do
    socket = new_socket |> Socket.put_topic("top:subtop")
    PubSub.subscribe(:phx_pub, socket.pid, "top:subtop")

    assert Channel.broadcast_from(:phx_pub, socket, "event", %{payload: "hello"})
    refute Enum.any?(Process.info(self)[:messages], &match?(%Message{}, &1))

    assert Channel.broadcast_from!(:phx_pub, socket, "event", %{payload: "hello"})
    refute Enum.any?(Process.info(self)[:messages], &match?(%Message{}, &1))
  end

  test "#broadcast_from and #broadcast_from! raises error when msg isn't a Map" do
    socket = Socket.put_topic(new_socket, "top:subtop")
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(:phx_pub, socket, "event", bar: "foo", foo: "bar")
    end
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from!(:phx_pub, socket, "event", bar: "foo", foo: "bar")
    end
  end

  test "#broadcast_from/4 and broadcast_from!/4 raises error when msg isn't a Map" do
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from(:phx_pub, self, "topic:subtopic", "event", bar: "foo")
    end
    assert_raise RuntimeError, message, fn ->
      Channel.broadcast_from!(:phx_pub, self, "topic:subtopic", "event", bar: "foo")
    end
  end

  test "#reply sends response to socket" do
    socket = Socket.put_topic(new_socket, "top:subtop")
    assert Channel.reply(socket, "event", %{payload: "hello"})

    assert Enum.any?(Process.info(self)[:messages], &match?({:socket_reply, %Message{}}, &1))
    assert_received {:socket_reply, %Message{
      topic: "top:subtop",
      event: "event",
      payload: %{payload: "hello"}
    }}
  end

  test "#reply raises friendly error when message arg isn't a Map" do
    socket = Socket.put_topic(new_socket, "top:subtop")
    message = "Message argument must be a map"
    assert_raise RuntimeError, message, fn ->
      Channel.reply(socket, "event", foo: "bar", bar: "foo")
    end
  end

  test "Default #leave is generated as a noop" do
    assert {:ok, %Socket{}} = BlankChannel.leave(%{}, new_socket)
  end

  test "#leave can be overridden" do
    assert MyChannel.leave(%{return: :overridden}, new_socket) == :overridden
  end

  test "handle_info handles anything that is sent to the socket directly" do
    message = join_message(fn socket -> {:ok, socket} end)
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    sock = HashDict.get(sockets, "topic1:subtopic")
    assert Socket.Server.authorized?(sock, "topic1:subtopic")
    send sock, "should:arrive"
    assert_receive :handle_info_triggered
  end

  test "handle_in and handle_out callbacks can return {:leave, socket} to leave channel" do
    # join
    join = fn ->
      message = join_message(fn socket -> {:ok, socket} end)
      assert subscribers(:phx_pub, "topic1:subtopic") == []
      Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    end

    # incoming leave
    {:ok, sockets} = join.()
    assert HashDict.get(sockets, "topic1:subtopic")
    assert subscribers(:phx_pub, "topic1:subtopic") == [self]
    # send message that returns {:leave, socket} now that we've joined
    message = %Message{topic: "topic1:subtopic",
                       event: "should:be:going",
                       payload: %{}}
    {:ok, socks} = Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    refute HashDict.get(socks, "topic1:subtopic")
    assert socks == HashDict.new
    assert subscribers(:phx_pub, "topic1:subtopic") == []
    assert_received :leave_triggered

    # outgoing leave
    {:ok, sockets} = join.()
    assert HashDict.get(sockets, "topic1:subtopic")
    assert subscribers(:phx_pub, "topic1:subtopic") == [self]
    # send broadcast that returns {:leave, socket} now that we've joined
    msg = %Message{event: "everyone:leave", topic: "topic1:subtopic", payload: %{}}
    {:ok, sockets} = Transport.dispatch_broadcast(sockets, msg)
    assert_received :everyone_leaving
    assert_received :leave_triggered
    refute HashDict.get(sockets, "topic1:subtopic")
    assert sockets == HashDict.new
    assert subscribers(:phx_pub, "topic1:subtopic") == []
  end

  test "successful join authorizes and subscribes socket to topic" do
    message = join_message(fn socket -> {:ok, socket} end)

    assert subscribers(:phx_pub, "topic1:subtopic") == []
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    socket = HashDict.get(sockets, "topic1:subtopic")
    assert socket
    assert Socket.Server.authorized?(socket, "topic1:subtopic")
    #assert socket.pid == self
    #assert subscribers(:phx_pub, "topic1:subtopic") == [socket.pid]
  end

  test "unsuccessful join denies socket access to topic" do
    message = join_message(fn _socket -> :ignore end)

    assert subscribers(:phx_pub, "topic1:subtopic") == []
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    refute HashDict.get(sockets, "topic1:subtopic")
    refute subscribers(:phx_pub, "topic1:subtopic") == [self]
  end

  test "#leave is called when the socket conn closes, and is unsubscribed" do
    message = join_message(fn socket -> {:ok, socket} end)

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert subscribers(:phx_pub, "topic1:subtopic") == [self]
    Transport.dispatch_leave(sockets, :reason)
    assert subscribers(:phx_pub, "topic1:subtopic") == []
  end

  test "#join raise InvalidReturn exception when return type invalid" do
    message = join_message(fn _socket -> :badreturn end)

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    end
  end

  test "#leave raise InvalidReturn exception when return type invalid" do
    message = join_message(fn socket -> {:ok, socket} end)

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    sock = HashDict.get(sockets, "topic1:subtopic")
    assert Socket.Server.authorized?(sock, "topic1:subtopic")
    assert_raise InvalidReturn, fn ->
      Transport.dispatch_leave(sockets, %{return: :badreturn})
      assert_received :on_leave_triggered
    end
  end

  test "#event raises InvalidReturn exception when return type is invalid" do
    message = join_message(fn socket -> {:ok, socket} end)

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    sock = HashDict.get(sockets, "topic1:subtopic")
    assert Socket.Server.authorized?(sock, "topic1:subtopic")
    message = %Message{topic: "topic1:subtopic",
                       event: "boom",
                       payload: fn _socket -> :badreturn end}

    assert_raise InvalidReturn, fn ->
      Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    end
  end

  test "returns heartbeat message when received, and does not store socket" do
    msg = %Message{topic: "phoenix", event: "heartbeat", payload: fn _socket -> :badreturn end}

    assert {:ok, sockets} = Transport.dispatch(msg, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert_receive {:socket_reply, %Message{topic: "phoenix", event: "heartbeat"}}
    assert sockets == HashDict.new
  end

  test "Socket state can be put and retrieved" do
    {:ok, socket} = MyChannel.handle_in("put", %{val: 123}, new_socket)
    {:ok, _socket} = MyChannel.handle_in("get", %{"key" => :val}, socket)
    assert_received 123
  end

  test "handle_out/3 can be overidden for custom broadcast handling" do
    message = join_message(fn socket -> {:ok, socket} end)

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    Transport.dispatch_broadcast(sockets, %Message{event: "some:broadcast",
                                                   topic: "topic1:subtopic",
                                                   payload: "hello"})
    assert_received :handle_out
  end

  test "join/3 and handle_in/3 match splat topics" do
    message = %Message{topic: "topic1:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert_received {:join, "topic1:somesubtopic"}

    message = %Message{topic: "topic1",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    refute_received {:join, "topic1"}

    message = %Message{topic: "topic1:somesubtopic",
                       event: "some:event",
                       payload: fn socket -> {:ok, socket} end}
    Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    assert_received {:handle_in, "topic1:somesubtopic"}

    message = %Message{topic: "topic1",
                       event: "some:event",
                       payload: fn socket -> {:ok, socket} end}
    Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    refute_received {:handle_in, "topic1:somesubtopic"}
  end

  test "join/3 and handle_in/3 match bare topics" do
    message = %Message{topic: "baretopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert HashDict.get(sockets, "baretopic")
    assert_received {:join, "baretopic"}

    message = %Message{topic: "baretopic:sub",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    refute HashDict.get(sockets, "baretopic:sub")
    refute_received {:join, "baretopic:sub"}

    message = %Message{topic: "baretopic",
                       event: "some:event",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    assert_received {:handle_in, "baretopic"}

    message = %Message{topic: "baretopic:sub",
                       event: "some:event",
                       payload: fn socket -> {:ok, socket} end}
    Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    refute_received {:handle_in, "baretopic:sub"}
  end

  test "channel `via:` option filters messages by transport" do
    # via WS
    message = %Message{topic: "wsonly:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert HashDict.get(sockets, "wsonly:somesubtopic")
    assert_received {:join, "wsonly:somesubtopic"}

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, LongPoller)
    refute HashDict.get(sockets, "wsonly:somesubtopic")
    refute_received {:join, "wsonly:somesubtopic"}

    # via LP
    message = %Message{topic: "lponly:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, LongPoller)
    assert HashDict.get(sockets, "lponly:somesubtopic")
    assert_received {:join, "lponly:somesubtopic"}

    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    refute HashDict.get(sockets, "lponly:somesubtopic")
    refute_received {:join, "lponly:somesubtopic"}
  end

  test "unmatched channel message ignores message" do
    msg = %Message{topic: "ensurebadmatch:somesubtopic",
                   event: "join",
                   payload: fn socket -> {:ok, socket} end}
    assert nil == Router.channel_for_topic(msg.topic, WebSocket)
    assert {:ok, sockets} =
      Transport.dispatch(msg, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert sockets == HashDict.new
    refute_received {:join, "ensurebadmatch:somesubtopic"}
  end

  test "socket/3 with alias option" do
    message = %Message{topic: "topic2:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert HashDict.get(sockets, "topic2:somesubtopic")
    assert_received {:join, "topic2:somesubtopic"}
  end

  test "socket/3 with alias applies :alias option" do
    message = %Message{topic: "topic3:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    {:ok, sockets} = Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, WebSocket)
    assert HashDict.get(sockets, "topic3:somesubtopic")
    assert_received {:join, "topic3:somesubtopic"}
  end

  test "socket/3 with via applies overridable transport filters to all channels" do
    message = %Message{topic: "topic2:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    assert {:ok, sockets} =
      Transport.dispatch(message, HashDict.new, self, Router, :phx_pub, LongPoller)
    assert sockets == HashDict.new
    refute_received {:join, "topic2:somesubtopic"}

    message = %Message{topic: "topic2-override:somesubtopic",
                       event: "join",
                       payload: fn socket -> {:ok, socket} end}
    assert {:ok, _sockets} = Transport.dispatch(message, sockets, self, Router, :phx_pub, LongPoller)
    assert_received {:join, "topic2-override:somesubtopic"}
    assert {:ok, sockets} =
      Transport.dispatch(message, sockets, self, Router, :phx_pub, WebSocket)
    assert sockets == HashDict.new
    refute_received {:join, "topic2-override:somesubtopic"}
  end
end
