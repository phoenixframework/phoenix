defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case, async: true

  config = [pubsub: [adapter: Phoenix.PubSub.PG2,
                     name: Phoenix.Test.ChannelTest.PubSub], server: false]
  Application.put_env(:phoenix, __MODULE__.Endpoint, config)

  alias Phoenix.Socket

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  defmodule Channel do
    use Phoenix.Channel

    intercept ["stop"]

    def join("foo:ok", _, socket) do
      {:ok, socket}
    end

    def join("foo:timeout", _, socket) do
      Process.flag(:trap_exit, true)
      {:ok, socket}
    end

    def join("foo:socket", _, socket) do
      socket = assign(socket, :hello, :world)
      {:ok, socket, socket}
    end

    def join("foo:error", %{"error" => reason}, _socket) do
      {:error, %{reason: reason}}
    end

    def join("foo:crash", %{}, _socket) do
      :unknown
    end

    def handle_in("broadcast", broadcast, socket) do
      broadcast_from! socket, "broadcast", broadcast
      {:noreply, socket}
    end

    def handle_in("noreply", %{"req" => arg}, socket) do
      push socket, "noreply", %{"resp" => arg}
      {:noreply, socket}
    end

    def handle_in("reply", %{"req" => arg}, socket) do
      {:reply, {:ok, %{"resp" => arg}}, socket}
    end

    def handle_in("reply", %{}, socket) do
      {:reply, :ok, socket}
    end

    def handle_in("async_reply", %{"req" => arg}, socket) do
      ref = socket_ref(socket)
      Task.start(fn -> reply(ref, {:ok, %{"async_resp" => arg}}) end)
      {:noreply, socket}
    end

    def handle_in("stop", %{"reason" => stop}, socket) do
      {:stop, stop, socket}
    end

    def handle_in("stop_and_reply", %{"req" => arg}, socket) do
      {:stop, :shutdown, {:ok, %{"resp" => arg}}, socket}
    end

    def handle_in("stop_and_reply", %{}, socket) do
      {:stop, :shutdown, :ok, socket}
    end

    def handle_in("subscribe", %{"topic" => topic}, socket) do
      subscribe(socket, topic)
      {:reply, :ok, socket}
    end

    def handle_in("unsubscribe", %{"topic" => topic}, socket) do
      unsubscribe(socket, topic)
      {:reply, :ok, socket}
    end

    def handle_out("stop", _payload, socket) do
      {:stop, :shutdown, socket}
    end

    def handle_info(:stop, socket) do
      {:stop, :shutdown, socket}
    end

    def handle_info(:push, socket) do
      push socket, "info", %{"reason" => "push"}
      {:noreply, socket}
    end

    def handle_info(:broadcast, socket) do
      broadcast_from socket, "info", %{"reason" => "broadcast"}
      {:noreply, socket}
    end

    def terminate(_reason, %{topic: "foo:timeout"}) do
      :timer.sleep(:infinity)
    end

    def terminate(reason, socket) do
      send socket.transport_pid, {:terminate, reason}
      :ok
    end
  end

  defmodule CodeChangeChannel do
    use Phoenix.Channel

    def join(_topic, _params, socket), do: {:ok, socket}

    def code_change(_old, _socket, _extra) do
      {:error, :cant}
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "foo:*", Channel

    transport :websocket, Phoenix.Transports.WebSocket

    def connect(params, socket) do
      if params["reject"] == true do
        :error
      else
        {:ok, socket}
      end
    end

    def id(_), do: "123"
  end


  @endpoint Endpoint
  use Phoenix.ChannelTest

  setup_all do
    @endpoint.start_link()
    :ok
  end

  ## socket

  test "socket/0" do
    assert socket() == %Socket{
      endpoint: @endpoint,
      pubsub_server: Phoenix.Test.ChannelTest.PubSub,
      transport: Phoenix.ChannelTest,
      transport_name: :channel_test,
      transport_pid: self(),
      serializer: Phoenix.ChannelTest.NoopSerializer
    }
  end

  test "socket/2" do
    assert socket("user:id", %{hello: :world}) == %Socket{
      id: "user:id",
      assigns: %{hello: :world},
      endpoint: @endpoint,
      pubsub_server: Phoenix.Test.ChannelTest.PubSub,
      transport: Phoenix.ChannelTest,
      transport_name: :channel_test,
      transport_pid: self(),
      serializer: Phoenix.ChannelTest.NoopSerializer
    }
  end

  ## join

  @tag :capture_log
  test "join/3 with success" do
    assert {:ok, socket, client} = join(socket("id", original: :assign), Channel, "foo:socket")
    assert socket.channel == Channel
    assert socket.endpoint == @endpoint
    assert socket.pubsub_server == Phoenix.Test.ChannelTest.PubSub
    assert socket.topic == "foo:socket"
    assert socket.transport == Phoenix.ChannelTest
    assert socket.transport_pid == self()
    assert socket.serializer == Phoenix.ChannelTest.NoopSerializer
    assert socket.assigns == %{hello: :world, original: :assign}
    assert %{socket | joined: true} == client

    {:links, links} = Process.info(self(), :links)
    assert client.channel_pid in links
  end

  @tag :capture_log
  test "join/3 with error reply" do
    assert {:error, %{reason: "mybad"}} =
             join(socket(), Channel, "foo:error", %{"error" => "mybad"})
  end

  @tag :capture_log
  test "join/3 with crash" do
    Process.flag(:trap_exit, true)
    Logger.disable(self())
    assert {:error, %{reason: "join crashed"}} = join(socket(), Channel, "foo:crash")
    assert_receive {:EXIT, _, _}
  end

  ## handle_in

  @tag :capture_log
  test "pushes and receives pushed messages" do
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    ref = push socket, "noreply", %{"req" => "foo"}
    assert_push "noreply", %{"resp" => "foo"}
    refute_reply ref, _status
  end

  @tag :capture_log
  test "pushes and receives replies" do
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")

    ref = push socket, "reply", %{}
    assert_reply ref, :ok
    refute_push _status, _payload

    ref = push socket, "reply", %{"req" => "foo"}
    assert_reply ref, :ok, %{"resp" => "foo"}
  end

  @tag :capture_log
  test "receives async replies" do
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")

    ref = push socket, "async_reply", %{"req" => "foo"}
    assert_reply ref, :ok, %{"async_resp" => "foo"}
  end

  @tag :capture_log
  test "pushes on stop" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    push socket, "stop", %{"reason" => :normal}
    pid = socket.channel_pid
    assert_receive {:terminate, :normal}
    assert_receive {:EXIT, ^pid, :normal}

    # Pushing after stop doesn't crash the client/transport
    Process.flag(:trap_exit, false)
    push socket, "stop", %{"reason" => :normal}
  end

  @tag :capture_log
  test "pushes and receives replies on stop" do
    Process.flag(:trap_exit, true)

    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{}
    assert_reply ref, :ok
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}

    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{"req" => "foo"}
    assert_reply ref, :ok, %{"resp" => "foo"}
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  @tag :capture_log
  test "pushes and broadcast messages" do
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    refute_broadcast "broadcast", _params
    push socket, "broadcast", %{"foo" => "bar"}
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  @tag :capture_log
  test "connects and joins topics directly" do
    :error = connect(UserSocket, %{"reject" => true})
    {:ok, socket} = connect(UserSocket, %{})
    socket = subscribe_and_join!(socket, "foo:ok")
    push socket, "broadcast", %{"foo" => "bar"}
    assert socket.id == "123"
    assert_broadcast "broadcast", %{"foo" => "bar"}

    {:ok, _, socket} = subscribe_and_join(socket, "foo:ok")
    push socket, "broadcast", %{"foo" => "bar"}
    assert socket.id == "123"
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  ## handle_out

  @tag :capture_log
  test "push broadcasts by default" do
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    broadcast_from! socket, "default", %{"foo" => "bar"}
    assert_push "default", %{"foo" => "bar"}
  end

  @tag :capture_log
  test "handles broadcasts and stops" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = subscribe_and_join(socket(), Channel, "foo:ok")
    broadcast_from! socket, "stop", %{"foo" => "bar"}
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  ## handle_info

  @tag :capture_log
  test "handles messages and stops" do
    Process.flag(:trap_exit, true)
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    pid = socket.channel_pid
    send pid, :stop
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  @tag :capture_log
  test "handles messages and pushes" do
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    send socket.channel_pid, :push
    assert_push "info", %{"reason" => "push"}
  end

  @tag :capture_log
  test "handles messages and broadcasts" do
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    send socket.channel_pid, :broadcast
    assert_broadcast "info", %{"reason" => "broadcast"}
  end

  ## terminate

  @tag :capture_log
  test "leaves the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    ref = leave(socket)
    assert_reply ref, :ok

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :left}}
    assert_receive {:EXIT, ^pid, {:shutdown, :left}}

    # Leaving again doesn't crash
    _ = leave(socket)
  end

  @tag :capture_log
  test "closes the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(), Channel, "foo:ok")
    close(socket)

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :closed}}
    assert_receive {:EXIT, ^pid, {:shutdown, :closed}}

    # Closing again doesn't crash
    _ = close(socket)
  end

  @tag :capture_log
  test "kills the channel when we reach timeout on close" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(), Channel, "foo:timeout")
    close(socket, 0)

    pid = socket.channel_pid
    assert_receive {:EXIT, ^pid, :killed}
    refute_received {:terminate, :killed}

    # Closing again doesn't crash
    _ = close(socket)
  end

  test "code_change/3 proxies to channel" do
    socket = %Socket{channel: Channel}
    assert Phoenix.Channel.Server.code_change(:old, socket, :extra) ==
      {:ok, socket}
  end

  test "code_change/3 is overridable" do
    socket = %Socket{channel: CodeChangeChannel}
    assert Phoenix.Channel.Server.code_change(:old, socket, :extra) ==
      {:error, :cant}
  end

  @tag :capture_log
  test "subscribe and subscribe" do
    socket = subscribe_and_join!(socket(), Channel, "foo:ok")
    socket.endpoint.broadcast!("another:topic", "event", %{})
    refute_receive %Phoenix.Socket.Message{}
    ref = push socket, "subscribe", %{"topic" => "another:topic"}
    assert_reply ref, :ok
    socket.endpoint.broadcast!("another:topic", "event", %{})
    assert_receive %Phoenix.Socket.Message{topic: "another:topic"}

    ref = push socket, "unsubscribe", %{"topic" => "another:topic"}
    assert_reply ref, :ok
    socket.endpoint.broadcast!("another:topic", "event", %{})
    refute_receive %Phoenix.Socket.Message{}
  end
end
