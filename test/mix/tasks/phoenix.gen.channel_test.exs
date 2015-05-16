Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Gen.ChannelTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates channel" do
    in_tmp "generates channel", fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Room", "rooms"]

      assert_file "web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.RoomChannel do|
        assert file =~ ~S|use Phoenix.Web, :channel|
        assert file =~ ~S|def join("rooms:lobby", payload, socket) do|
        assert file =~ ~S|def handle_in("ping", payload, socket) do|
        assert file =~ ~S|{:reply, {:pong, payload}, socket}|
        assert file =~ ~S|def handle_in("shout", payload, socket) do|
        assert file =~ ~S|broadcast socket, "shout", payload|
        assert file =~ ~S|{:noreply, socket}|
        assert file =~ ~S|def handle_out(event, payload, socket) do|
        assert file =~ ~S|push socket, event, payload|
      end

      assert_file "test/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.RoomChannelTest|
        assert file =~ ~S|use Phoenix.ChannelCase|

        assert file =~ ~S|test "successful join of rooms:lobby" do|
        assert file =~ ~S|assert {:ok, _, socket} = join(RoomChannel, "rooms:lobby")|
        assert file =~ ~S|assert socket.topic == "rooms:lobby"|

        assert file =~ ~S|test "ping replies with pong" do|
        assert file =~ ~S|{:ok, _, socket} = join(RoomChannel, "rooms:lobby")|
        assert file =~ ~S|ref = push socket, "ping", %{"hello" => "there"}|
        assert file =~ ~S|assert_reply ref, :pong, %{"hello" => "there"}|

        assert file =~ ~S|test "shout broadcasts to rooms:lobby" do|
        assert file =~ ~S|{:ok, _, socket} = subscribe_and_join(RoomChannel, "rooms:lobby")|
        assert file =~ ~S|push socket, "broadcast", %{"foo" => "bar"}|
        assert file =~ ~S|assert_broadcast "broadcast", %{"foo" => "bar"}|
      end
    end
  end

  test "generates nested channel" do
    in_tmp "generates nested channel", fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Admin.Room", "rooms"]

      assert_file "web/channels/admin/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Admin.RoomChannel do|
        assert file =~ ~S|use Phoenix.Web, :channel|
      end
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Admin.Room", "rooms", "new_message"]
    end
  end
end
