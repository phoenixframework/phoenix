Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupChannel do
end

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
        assert file =~ ~S|{:reply, {:ok, payload}, socket}|
        assert file =~ ~S|def handle_in("shout", payload, socket) do|
        assert file =~ ~S|broadcast socket, "shout", payload|
        assert file =~ ~S|{:noreply, socket}|

        assert file =~ ~S|def handle_out(event, payload, socket) do|
        assert file =~ ~S|push socket, event, payload|
      end

      assert_file "test/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.RoomChannelTest|
        assert file =~ ~S|use Phoenix.ChannelCase|
        assert file =~ ~S|alias Phoenix.RoomChannel|

        assert file =~ ~S|test "ping replies with status ok"|
        assert file =~ ~S|ref = push socket, "ping", %{"hello" => "there"}|
        assert file =~ ~S|assert_reply ref, :ok, %{"hello" => "there"}|

        assert file =~ ~S|test "shout broadcasts to rooms:lobby"|
        assert file =~ ~S|push socket, "shout", %{"hello" => "all"}|
        assert file =~ ~S|assert_broadcast "shout", %{"hello" => "all"}|

        assert file =~ ~S|test "broadcasts are pushed to the client"|
        assert file =~ ~S|broadcast_from! socket, "broadcast", %{"some" => "data"}|
        assert file =~ ~S|assert_push "broadcast", %{"some" => "data"}|
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

      assert_file "test/channels/admin/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.Admin.RoomChannelTest|
        assert file =~ ~S|use Phoenix.ChannelCase|
        assert file =~ ~S|alias Phoenix.Admin.RoomChannel|
      end
    end
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run []
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Admin.Room", "rooms", "new_message"]
    end
  end

  test "name can't already be defined" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Dup", "dups"]
    end
  end
end
