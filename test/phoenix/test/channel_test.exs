defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case, async: true

  config = [pubsub: [adapter: Phoenix.PubSub.PG2,
                     name: Phoenix.Test.ChannelTest.PubSub], server: false]
  Application.put_env(:phoenix, __MODULE__.Endpoint, config)

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

  @endpoint Endpoint
  use Phoenix.ChannelTest

  setup_all do
    @endpoint.start_link()
    :ok
  end

  ## join

  test "join/3 with success" do
    assert {:ok, socket, client} = join(Channel, "foo:socket")
    assert socket.channel == Channel
    assert socket.endpoint == @endpoint
    assert socket.pubsub_server == Phoenix.Test.ChannelTest.PubSub
    assert socket.topic == "foo:socket"
    assert socket.transport == Phoenix.ChannelTest
    assert socket.transport_pid == self()
    assert socket.serializer == Phoenix.ChannelTest.NoopSerializer
    assert socket.assigns == %{hello: :world}
    assert %{socket | joined: true} == client

    {:links, links} = Process.info(self(), :links)
    assert client.channel_pid in links
  end

  test "join/3 with error reply" do
    assert {:error, %{reason: "mybad"}} =
             join(Channel, "foo:error", %{"error" => "mybad"})
  end

  test "join/3 with crash" do
    Process.flag(:trap_exit, true)
    Logger.disable(self())
    assert {:error, %{reason: "join crashed"}} = join(Channel, "foo:crash")
    assert_receive {:EXIT, _, _}
  end

  ## handle_in

  test "pushes and receives pushed messages" do
    {:ok, _, socket} = join(Channel, "foo:ok")
    push socket, "noreply", %{"req" => "foo"}
    assert_push "noreply", %{"resp" => "foo"}
  end

  test "pushes and receives replies" do
    {:ok, _, socket} = join(Channel, "foo:ok")

    ref = push socket, "reply", %{}
    assert_reply ref, :ok

    ref = push socket, "reply", %{"req" => "foo"}
    assert_reply ref, :ok, %{"resp" => "foo"}
  end

  test "pushes on stop" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(Channel, "foo:ok")
    push socket, "stop", %{"reason" => :normal}
    pid = socket.channel_pid
    assert_receive {:terminate, :normal}
    assert_receive {:EXIT, ^pid, :normal}

    # Pushing after stop doesn't crash the client/transport
    Process.flag(:trap_exit, false)
    push socket, "stop", %{"reason" => :normal}
  end

  test "pushes and receives replies on stop" do
    Process.flag(:trap_exit, true)

    {:ok, _, socket} = join(Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{}
    assert_reply ref, :ok
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}

    {:ok, _, socket} = join(Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{"req" => "foo"}
    assert_reply ref, :ok, %{"resp" => "foo"}
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  test "pushes and broadcast messages" do
    socket = subscribe_and_join!(Channel, "foo:ok")
    push socket, "broadcast", %{"foo" => "bar"}
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  ## handle_out

  test "push broadcasts by default" do
    socket = subscribe_and_join!(Channel, "foo:ok")
    broadcast_from! socket, "default", %{"foo" => "bar"}
    assert_push "default", %{"foo" => "bar"}
  end

  test "handles broadcasts and stops" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = subscribe_and_join(Channel, "foo:ok")
    broadcast_from! socket, "stop", %{"foo" => "bar"}
    pid = socket.channel_pid
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  ## handle_info

  test "handles messages and stops" do
    Process.flag(:trap_exit, true)
    socket = subscribe_and_join!(Channel, "foo:ok")
    pid = socket.channel_pid
    send pid, :stop
    assert_receive {:terminate, :shutdown}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  test "handles messages and pushes" do
    socket = subscribe_and_join!(Channel, "foo:ok")
    send socket.channel_pid, :push
    assert_push "info", %{"reason" => "push"}
  end

  test "handles messages and broadcasts" do
    socket = subscribe_and_join!(Channel, "foo:ok")
    send socket.channel_pid, :broadcast
    assert_broadcast "info", %{"reason" => "broadcast"}
  end

  ## terminate

  test "leaves the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(Channel, "foo:ok")
    ref = leave(socket)
    assert_reply ref, :ok

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :left}}
    assert_receive {:EXIT, ^pid, {:shutdown, :left}}

    # Leaving again doesn't crash
    _ = leave(socket)
  end

  test "closes the channel" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(Channel, "foo:ok")
    close(socket)

    pid = socket.channel_pid
    assert_receive {:terminate, {:shutdown, :closed}}
    assert_receive {:EXIT, ^pid, {:shutdown, :closed}}

    # Closing again doesn't crash
    _ = close(socket)
  end

  test "kills the channel when we reach timeout on close" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(Channel, "foo:timeout")
    close(socket, 0)

    pid = socket.channel_pid
    assert_receive {:EXIT, ^pid, :killed}
    refute_received {:terminate, :killed}

    # Closing again doesn't crash
    _ = close(socket)
  end
end
