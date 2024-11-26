defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message}
  alias __MODULE__.{UserSocket, Endpoint}

  Application.put_env(:phoenix, Endpoint,
    pubsub_server: Phoenix.Test.ChannelTest.PubSub,
    server: false
  )

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/socket", UserSocket
  end

  defmodule EmptyChannel do
    use Phoenix.Channel

    def join(_, _, socket), do: {:ok, socket}

    def handle_in(_event, _params, socket) do
      {:reply, :ok, socket}
    end
  end

  defmodule Channel do
    use Phoenix.Channel

    intercept ["stop"]

    def join("foo:ok", _, socket) do
      {:ok, socket}
    end

    def join("foo:external", _, socket) do
      :ok = Phoenix.PubSub.subscribe(Phoenix.Test.ChannelTest.PubSub, "external:topic")
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

    def join("foo:payload", %{"string" => _payload}, socket) do
      {:ok, socket}
    end

    def handle_in("broadcast", broadcast, socket) do
      broadcast_from!(socket, "broadcast", broadcast)
      {:noreply, socket}
    end

    def handle_in("noreply", %{"req" => arg}, socket) do
      push(socket, "noreply", %{"resp" => arg})
      {:noreply, socket}
    end

    def handle_in("reply", %{"req" => arg}, socket) do
      {:reply, {:ok, %{"resp" => arg}}, socket}
    end

    def handle_in("reply", %{}, socket) do
      {:reply, :ok, socket}
    end

    def handle_in("crash", %{}, _socket) do
      raise "boom!"
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

    def handle_out("stop", _payload, socket) do
      {:stop, :shutdown, socket}
    end

    def handle_info(%Broadcast{event: event, payload: payload}, socket) do
      push(socket, event, payload)
      {:noreply, socket}
    end

    def handle_info(:stop, socket) do
      {:stop, :shutdown, socket}
    end

    def handle_info(:push, socket) do
      push(socket, "info", %{"reason" => "push"})
      {:noreply, socket}
    end

    def handle_info(:broadcast, socket) do
      broadcast_from(socket, "info", %{"reason" => "broadcast"})
      {:noreply, socket}
    end

    def handle_call(:ping, _from, socket) do
      {:reply, :pong, socket}
    end

    def handle_cast({:ping, ref, sender}, socket) do
      send(sender, {ref, :pong})
      {:noreply, socket}
    end

    def terminate(_reason, %{topic: "foo:timeout"}) do
      :timer.sleep(:infinity)
    end

    def terminate(reason, socket) do
      send(socket.transport_pid, {:terminate, reason})
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

    channel "foo:*", Channel, assigns: %{user_socket_assigns: true}

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
  @moduletag :capture_log
  import Phoenix.ChannelTest

  setup_all do
    start_supervised! @endpoint
    start_supervised! {Phoenix.PubSub, name: Phoenix.Test.ChannelTest.PubSub}
    :ok
  end

  defp assert_graceful_exit(pid) do
    assert_receive {:socket_close, ^pid, _}
  end

  ## socket

  test "socket/1" do
    assert %Socket{
             endpoint: @endpoint,
             handler: UserSocket,
             pubsub_server: Phoenix.Test.ChannelTest.PubSub,
             serializer: Phoenix.ChannelTest.NoopSerializer
           } = socket(UserSocket)
  end

  test "socket/3" do
    assert %Socket{
             id: "user:id",
             assigns: %{hello: :world},
             endpoint: @endpoint,
             pubsub_server: Phoenix.Test.ChannelTest.PubSub,
             serializer: Phoenix.ChannelTest.NoopSerializer,
             handler: UserSocket
           } = socket(UserSocket, "user:id", %{hello: :world})
  end

  test "socket/4" do
    pid = self()

    task =
      Task.async(fn ->
        assert %Socket{
                 id: "user:id",
                 assigns: %{hello: :world},
                 endpoint: @endpoint,
                 pubsub_server: Phoenix.Test.ChannelTest.PubSub,
                 serializer: Phoenix.ChannelTest.NoopSerializer,
                 handler: UserSocket
               } = socket(UserSocket, "user:id", %{hello: :world}, test_process: pid)
      end)

    Task.await(task)
  end

  ## join

  test "join/3 with success" do
    assert {:ok, socket, client} =
             join(socket(UserSocket, "id", original: :assign), Channel, "foo:socket")

    assert socket.channel == Channel
    assert socket.endpoint == @endpoint
    assert socket.pubsub_server == Phoenix.Test.ChannelTest.PubSub
    assert socket.topic == "foo:socket"
    assert {Phoenix.ChannelTest, _} = socket.transport
    assert socket.transport_pid == self()
    assert socket.serializer == Phoenix.ChannelTest.NoopSerializer
    assert socket.assigns == %{hello: :world, original: :assign}
    assert %{socket | joined: true} == client

    {:links, links} = Process.info(self(), :links)
    assert client.channel_pid in links

    {:dictionary, dictionary} = Process.info(client.channel_pid, :dictionary)
    assert dictionary[:"$callers"] == [self()]
  end

  test "join/3 from another process" do
    socket = socket(UserSocket, "id", original: :assign)

    assert {:ok, socket, client} =
             Task.async(fn ->
               join(socket, Channel, "foo:socket")
              end)
              |> Task.await()

    assert %{socket | joined: true} == client
  end

  test "join/3 with error reply" do
    assert {:error, %{reason: "mybad"}} =
             join(socket(UserSocket), Channel, "foo:error", %{"error" => "mybad"})
  end

  test "join/3 with crash" do
    Process.flag(:trap_exit, true)
    Logger.disable(self())
    assert {:error, %{reason: "join crashed"}} = join(socket(UserSocket), Channel, "foo:crash")
  end

  ## handle_in

  test "pushes and receives pushed messages" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    ref = push(socket, "noreply", %{"req" => "foo"})
    assert_push "noreply", %{"resp" => "foo"}
    refute_reply ref, _status
  end

  test "pushes and receives replies" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")

    ref = push(socket, "reply", %{})
    assert_reply ref, :ok
    refute_push _status, _payload

    ref = push(socket, "reply", %{"req" => "foo"})
    assert_reply ref, :ok, %{"resp" => "foo"}
  end

  test "works with list data structures" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    ref = push(socket, "reply", %{req: [%{bar: "baz"}, %{bar: "foo"}]})
    assert_reply ref, :ok, %{"resp" => [%{"bar" => "baz"}, %{"bar" => "foo"}]}
  end

  test "receives async replies" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")

    ref = push(socket, "async_reply", %{"req" => "foo"})
    assert_reply ref, :ok, %{"async_resp" => "foo"}
  end

  test "crashed channel propagates exit" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    push(socket, "crash", %{})
    pid = socket.channel_pid
    assert_receive {:terminate, _}
    assert_receive {:EXIT, ^pid, _}
    refute_receive {:socket_close, _, _}
  end

  test "pushes on stop" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    push(socket, "stop", %{"reason" => :normal})
    pid = socket.channel_pid
    assert_receive {:terminate, :normal}
    assert_graceful_exit(pid)

    # Pushing after stop doesn't crash the client/transport
    Process.flag(:trap_exit, false)
    push(socket, "stop", %{"reason" => :normal})
  end

  test "pushes and receives replies on stop" do
    Process.flag(:trap_exit, true)

    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    ref = push(socket, "stop_and_reply", %{})
    assert_reply ref, :ok
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_graceful_exit(pid)

    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    ref = push(socket, "stop_and_reply", %{"req" => "foo"})
    assert_reply ref, :ok, %{"resp" => "foo"}
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_graceful_exit(pid)
  end

  test "pushes and broadcast messages" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    refute_broadcast "broadcast", _params
    push(socket, "broadcast", %{"foo" => "bar"})
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  test "connects and joins topics directly" do
    :error = connect(UserSocket, %{"reject" => true})
    {:ok, socket} = connect(UserSocket, %{})
    socket = subscribe_and_join!(socket, "foo:ok")
    push(socket, "broadcast", %{"foo" => "bar"})
    assert socket.id == "123"
    assert_broadcast "broadcast", %{"foo" => "bar"}

    {:ok, _, socket} = subscribe_and_join(socket, "foo:ok")
    push(socket, "broadcast", %{"foo" => "bar"})
    assert socket.id == "123"
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  test "connects and joins topics directly, from another process" do
    pid = self()

    task =
      Task.async(fn ->
        {:ok, socket} = connect(UserSocket, %{}, test_process: pid)
        socket = subscribe_and_join!(socket, "foo:ok")
        push(socket, "broadcast", %{"foo" => "bar"})
        assert socket.id == "123"
        assert_broadcast "broadcast", %{"foo" => "bar"}
      end)

    Task.await(task)
  end

  test "pushes atom parameter keys as strings" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")

    ref = push(socket, "reply", %{req: %{parameter: 1}})
    assert_reply ref, :ok, %{"resp" => %{"parameter" => 1}}
  end

  test "pushes structs without modifying them" do
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    date = ~D[2010-04-17]

    ref = push(socket, "reply", %{req: date})
    assert_reply ref, :ok, %{"resp" => ^date}
  end

  test "connects with atom parameter keys as strings" do
    :error = connect(UserSocket, %{reject: true})
  end

  ## handle_out

  test "push broadcasts by default" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    broadcast_from!(socket, "default", %{"foo" => "bar"})
    assert_push "default", %{"foo" => "bar"}
  end

  test "push broadcasts by default, outside of test process" do
    pid = self()

    task =
      Task.async(fn ->
        socket =
          subscribe_and_join!(
            socket(UserSocket, "user_id", %{some: :assign}, test_process: pid),
            Channel,
            "foo:ok"
          )

        broadcast_from!(socket, "default", %{"foo" => "bar"})
        assert_push "default", %{"foo" => "bar"}
      end)

    Task.await(task)
  end

  test "handles broadcasts and stops" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = subscribe_and_join(socket(UserSocket), Channel, "foo:ok")
    broadcast_from!(socket, "stop", %{"foo" => "bar"})
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_graceful_exit(pid)
  end

  ## handle_info

  test "handles messages and stops" do
    Process.flag(:trap_exit, true)
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    pid = socket.channel_pid
    send(pid, :stop)
    assert_receive {:terminate, :shutdown}
    assert_graceful_exit(pid)
  end

  test "handles messages and pushes" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    send(socket.channel_pid, :push)
    assert_push "info", %{"reason" => "push"}
  end

  test "handles messages and broadcasts" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    send(socket.channel_pid, :broadcast)
    assert_broadcast "info", %{"reason" => "broadcast"}
  end

  ## handle_call/cast

  test "handles calls" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    assert GenServer.call(socket.channel_pid, :ping) == :pong
  end

  test "handles casts" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:ok")
    ref = make_ref()
    :ok = GenServer.cast(socket.channel_pid, {:ping, ref, self()})
    assert_receive {^ref, :pong}
  end

  ## terminate

  test "leaves the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    ref = leave(socket)
    assert_reply ref, :ok

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :left}}
    assert_graceful_exit(pid)

    # Leaving again doesn't crash
    _ = leave(socket)
  end

  test "closes the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:ok")
    close(socket)

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :closed}}
    assert_receive {:EXIT, ^pid, {:shutdown, :closed}}

    # Closing again doesn't crash
    _ = close(socket)
  end

  test "kills the channel when we reach timeout on close" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(socket(UserSocket), Channel, "foo:timeout")
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

  test "external subscriptions" do
    socket = subscribe_and_join!(socket(UserSocket), Channel, "foo:external")
    socket.endpoint.broadcast!("external:topic", "external_event", %{one: 1})
    assert_receive %Message{topic: "foo:external", event: "external_event", payload: %{one: 1}}
  end

  test "warns on unhandled handle_info/2 messages" do
    socket = subscribe_and_join!(socket(UserSocket), EmptyChannel, "topic")

    assert ExUnit.CaptureLog.capture_log(fn ->
             send(socket.channel_pid, :unhandled)
             ref = push(socket, "hello", %{})
             assert_reply ref, :ok
           end) =~ "received unexpected message in handle_info/2: :unhandled"
  end

  test "subscribes to socket.id and receives disconnects" do
    {:ok, socket} = connect(UserSocket, %{})
    socket.endpoint.broadcast!(socket.id, "disconnect", %{})
    assert_broadcast "disconnect", %{}
  end

  test "supports static assigns in user socket channel definition" do
    {:ok, socket} = connect(UserSocket, %{})
    socket = subscribe_and_join!(socket, "foo:ok")
    assert socket.assigns.user_socket_assigns
  end

  test "converts payload on join to string keyed" do
    {:ok, socket} = connect(UserSocket, %{})
    assert {:ok, _, _socket} = subscribe_and_join(socket, "foo:payload", %{string: nil})
  end
end
