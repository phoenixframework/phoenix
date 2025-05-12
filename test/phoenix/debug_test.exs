defmodule Phoenix.DebugTest do
  use ExUnit.Case, async: true

  alias Phoenix.Debug

  # we cannot easily test the Phoenix.Debug functions with the regular
  # Phoenix.ChannelTest functions, because they use the test process
  # itself as the transport process
  defmodule FakeSocket do
    use GenServer

    def init(channel_pid) do
      Process.put(:"$process_label", {Phoenix.Socket, __MODULE__, nil})
      {:ok, channel_pid}
    end

    def handle_info({:debug_channels, ref, reply_to}, state) do
      send(
        reply_to,
        {:debug_channels, ref, [%{pid: state, status: :joined, topic: "room:lobby"}]}
      )

      {:noreply, state}
    end
  end

  defmodule FakeChannel do
    use GenServer

    def init(state) do
      Process.put(:"$process_label", {Phoenix.Channel, __MODULE__.Channel, "room:lobby"})
      {:ok, state}
    end

    def handle_call(:socket, _from, state) do
      {:reply, %Phoenix.Socket{}, state}
    end
  end

  setup do
    {:ok, channel_pid} = GenServer.start_link(FakeChannel, nil)
    {:ok, socket_pid} = GenServer.start_link(FakeSocket, channel_pid)

    %{socket_pid: socket_pid, channel_pid: channel_pid}
  end

  describe "list_sockets/0" do
    test "returns a list of all currently connected channel socket processes", %{
      socket_pid: socket_pid
    } do
      sockets = Debug.list_sockets()
      assert is_list(sockets)
      assert Enum.any?(sockets, fn s -> s.pid == socket_pid end)
      assert Enum.find(sockets, fn s -> s.module == __MODULE__.FakeSocket end)
    end
  end

  describe "socket_process?/1" do
    test "returns true if the given pid is a channel socket process", %{socket_pid: socket_pid} do
      assert Debug.socket_process?(socket_pid)
    end

    test "returns false for a non-socket process" do
      refute Debug.socket_process?(self())
    end
  end

  describe "channel_process?/1" do
    test "returns true if the given pid is a channel process", %{channel_pid: channel_pid} do
      assert Debug.channel_process?(channel_pid)
    end

    test "returns false for a non-channel process" do
      refute Debug.channel_process?(self())
    end
  end

  describe "list_channels/1" do
    test "returns a list of all channels for a given socket pid", %{
      socket_pid: socket_pid,
      channel_pid: channel_pid
    } do
      {:ok, channels} = Debug.list_channels(socket_pid)
      assert is_list(channels)
      assert Enum.any?(channels, fn ch -> ch.pid == channel_pid and ch.topic == "room:lobby" end)
    end

    test "returns error for non-socket pid" do
      assert {:error, :not_alive} = Debug.list_channels(self())
    end
  end

  describe "socket/1" do
    test "returns the socket struct for a channel process", %{channel_pid: channel_pid} do
      assert {:ok, %Phoenix.Socket{}} = Debug.socket(channel_pid)
    end

    test "returns error for non-channel process" do
      assert {:error, :not_alive_or_not_a_channel} = Debug.socket(self())
    end
  end
end
