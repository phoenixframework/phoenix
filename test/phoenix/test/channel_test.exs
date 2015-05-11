defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case

  config = [server: false, pubsub: [name: :phx_pub]]
  Application.put_env(:phoenix, __MODULE__.Endpoint, config)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  @endpoint Endpoint

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

  use Phoenix.ChannelTest

  ## join

  test "join/3 with success" do
    assert {:ok, socket, pid} = join(Channel, "foo:socket")
    assert socket.endpoint == @endpoint
    assert socket.pubsub_server == :phx_pub
    assert socket.topic == "foo:socket"
    assert socket.transport == Phoenix.ChannelTest
    assert socket.transport_pid == self()

    {:links, links} = Process.info(self(), :links)
    assert pid in links
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
    {:ok, _, pid} = join(Channel, "foo:ok")
    push pid, "noreply", %{"req" => "foo"}
    assert_pushed "noreply", %{"resp" => "foo"}
  end

  test "pushes and receives replies" do
    {:ok, _, pid} = join(Channel, "foo:ok")

    ref = push pid, "reply", %{}
    assert_replied ref, :ok

    ref = push pid, "reply", %{"req" => "foo"}
    assert_replied ref, :ok, %{"resp" => "foo"}
  end

  test "pushes on stop" do
    Process.flag(:trap_exit, true)
    {:ok, _, pid} = join(Channel, "foo:ok")
    push pid, "stop", %{"reason" => :normal}
    assert_receive {:EXIT, ^pid, :normal}

    # Pushing after stop doesn't crash the client/transport
    Process.flag(:trap_exit, false)
    push pid, "stop", %{"reason" => :normal}
  end

  test "pushes and receives replies on stop" do
    Process.flag(:trap_exit, true)

    {:ok, _, pid} = join(Channel, "foo:ok")
    ref = push pid, "stop_and_reply", %{}
    assert_replied ref, :ok
    assert_receive {:EXIT, ^pid, :shutdown}

    {:ok, _, pid} = join(Channel, "foo:ok")
    ref = push pid, "stop_and_reply", %{"req" => "foo"}
    assert_replied ref, :ok, %{"resp" => "foo"}
    assert_receive {:EXIT, ^pid, :shutdown}
  end

  test "pushes and broadcast messages" do
    {:ok, _, pid} = join(Channel, "foo:ok")
    @endpoint.subscribe(self(), "foo:ok")
    push pid, "broadcast", %{"foo" => "bar"}
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
