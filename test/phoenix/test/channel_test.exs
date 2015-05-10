defmodule Phoenix.Test.ChannelTest do
  use ExUnit.Case

  defmodule Endpoint do
    def __pubsub_server__(), do: :phx_pub
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
  end

  use Phoenix.ChannelTest

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

  test "pushes and receives pushed messages" do
    {:ok, _, pid} = join(Channel, "foo:ok")
    push pid, "noreply", %{"req" => "foo"}
    assert_pushed "noreply", %{"resp" => "foo"}
  end

  test "pushes and receives replies" do
    {:ok, _, pid} = join(Channel, "foo:ok")

    ref = push pid, "reply", %{"req" => "foo"}
    assert_replied ref, :ok, %{"resp" => "foo"}

    ref = push pid, "reply", %{}
    assert_replied ref, :ok, %{}
  end
end
