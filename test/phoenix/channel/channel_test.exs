defmodule Phoenix.Channel.ChannelTest do
  use ExUnit.Case
  use Jazz
  alias Phoenix.Topic
  alias Phoenix.Channel
  alias Phoenix.Socket
  alias Phoenix.Socket.Handler
  alias Phoenix.Socket.Handler.InvalidReturn

  def new_socket do
    %Socket{pid: self,
            router: nil,
            channel: "somechan",
            channels: [],
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

    assert Channel.broadcast(socket, "event", foo: "bar")
  end

  test "#broadcast_from broadcasts message on channel from publisher" do
    Topic.create("chan:topic")
    socket = Socket.set_current_channel(new_socket, "chan", "topic")

    assert Channel.broadcast_from(socket, "event", message: "hello")
    _message = JSON.encode!(%{message: "hello"})
    refute_received _message
  end

  test "#reply sends response to socket" do
    socket = Socket.set_current_channel(new_socket, "chan", "topic")
    assert Channel.reply(socket, "event", message: "hello")
    _message = JSON.encode!(%{message: "hello"})
    assert_received _message
  end

  test "Default #leave is generated as a noop" do
    defmodule Chan1 do
      use Phoenix.Channel
    end
    socket = new_socket
    assert Chan1.leave(socket, []) == socket
  end

  test "#leave can be overridden" do
    defmodule Chan2 do
      use Phoenix.Channel
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

    socket = %Socket{pid: self, router: Router3, channel: "chan3"}
    message  = """
    {"channel": "chan3","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan3:topic")
    assert Topic.subscribers("chan3:topic") == []
    refute Socket.authenticated?(socket, "chan3", "topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)
    assert Socket.authenticated?(socket, "chan3", "topic")
    assert Topic.subscribers("chan3:topic") == [socket.pid]
  end

  test "unsuccessful join denies socket access to channel/topic" do
    defmodule Chan4 do
      use Phoenix.Channel
      def join(socket, _topic, _msg), do: {:error, socket, :unauthenticated}
    end
    defmodule Router4 do
      use Phoenix.Router
      use Phoenix.Router.Socket, mount: "/ws"
      channel "chan4", Chan4
    end

    socket = %Socket{pid: self, router: Router4, channel: "chan4"}
    message  = """
    {"channel": "chan4","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan4:topic")
    assert Topic.subscribers("chan4:topic") == []
    refute Socket.authenticated?(socket, "chan4", "topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)
    refute Socket.authenticated?(socket, "chan4", "topic")
    refute Topic.subscribers("chan4:topic") == [socket.pid]
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

    message  = """
    {"channel": "chan5","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan5:topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)
    Handler.websocket_terminate(:reason, socket.conn, socket)
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

    message  = """
    {"channel": "chan6","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan6:topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)
    Handler.websocket_info(:stuff, socket.conn, socket)
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
    message  = """
    {"channel": "chan7","topic":"topic","event":"join","message":"{}"}
    """
    assert_raise InvalidReturn, fn ->
      Handler.websocket_handle({:text, message}, nil, socket)
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
    message  = """
    {"channel": "chan8","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan6:topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)

    assert_raise InvalidReturn, fn ->
      Handler.websocket_terminate(:reason, socket.conn, socket)
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
    socket = %Socket{pid: self, router: Router9, channel: "chan9"}
    message  = """
    {"channel": "chan9","topic":"topic","event":"join","message":"{}"}
    """
    Topic.create("chan9:topic")
    refute Socket.authenticated?(socket, "chan9", "topic")
    {:ok, _req, socket} = Handler.websocket_handle({:text, message}, nil, socket)
    assert Socket.authenticated?(socket, "chan9", "topic")
    message  = """
    {"channel": "chan9","topic":"topic","event":"boom","message":"{}"}
    """
    assert_raise InvalidReturn, fn ->
      Handler.websocket_handle({:text, message}, nil, socket)
    end
  end
end

