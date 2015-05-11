defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case

  config = [pubsub: [adapter: Phoenix.PubSub.PG2,
                     name: Phoenix.Test.ChannelTest.PubSub], server: false]
  Application.put_env(:phoenix, __MODULE__.Endpoint, config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  defmodule Channel do
    use Phoenix.Channel

    def join("foo:ok", _, socket) do
      {:ok, socket}
    end

    def join("foo:socket", _, socket) do
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
    assert {:error, %{reason: "join crashed"}} = join(Channel, "foo:crash")
    assert_receive {:EXIT, _, _}
  end

  ## handle_in

  test "pushes and receives pushed messages" do
    {:ok, _, socket} = join(Channel, "foo:ok")
    push socket, "noreply", %{"req" => "foo"}
    assert_pushed "noreply", %{"resp" => "foo"}
  end

  test "pushes and receives replies" do
    {:ok, _, socket} = join(Channel, "foo:ok")

    ref = push socket, "reply", %{}
    assert_replied ref, :ok

    ref = push socket, "reply", %{"req" => "foo"}
    assert_replied ref, :ok, %{"resp" => "foo"}
  end

  test "pushes on stop" do
    Process.flag(:trap_exit, true)
    {:ok, _, socket} = join(Channel, "foo:ok")
    push socket, "stop", %{"reason" => :normal}
    pid = socket.channel_pid
    assert_receive {:EXIT, ^pid, :normal}

    # Pushing after stop doesn't crash the client/transport
    Process.flag(:trap_exit, false)
    push socket, "stop", %{"reason" => :normal}
  end

  test "pushes and receives replies on stop" do
    Process.flag(:trap_exit, true)

    {:ok, _, socket} = join(Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{}
    assert_replied ref, :ok
    pid = socket.channel_pid
    assert_receive {:EXIT, ^pid, :shutdown}

    {:ok, _, socket} = join(Channel, "foo:ok")
    ref = push socket, "stop_and_reply", %{"req" => "foo"}
    assert_replied ref, :ok, %{"resp" => "foo"}
    pid = socket.channel_pid
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  test "pushes and broadcast messages" do
    {:ok, _, socket} = join(Channel, "foo:ok")
    @endpoint.subscribe(self(), "foo:ok")
    push socket, "broadcast", %{"foo" => "bar"}
    assert_broadcast "broadcast", %{"foo" => "bar"}
  end

  ## handle_out

  test "pushes broadcasts by default" do
    {:ok, _, _} = join(Channel, "foo:ok")
    @endpoint.subscribe(self(), "foo:ok")
    @endpoint.broadcast_from(self(), "foo:ok", "default", %{"foo" => "bar"})
    assert_pushed "default", %{"foo" => "bar"}
  end
end
