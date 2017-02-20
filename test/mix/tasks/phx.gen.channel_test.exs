Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.Dup2Channel do
end

defmodule Mix.Tasks.Phx.Gen.ChannelTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  @moduletag :capture_io

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates channel" do
    in_tmp "generates channel", fn ->
      Gen.Channel.run ["Room"]

      assert_file "lib/web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.RoomChannel do|
        assert file =~ ~S|use Phoenix.Web, :channel|
        assert file =~ ~S|def join("room:lobby", payload, socket) do|

        assert file =~ ~S|def handle_in("ping", payload, socket) do|
        assert file =~ ~S|{:reply, {:ok, payload}, socket}|
        assert file =~ ~S|def handle_in("shout", payload, socket) do|
        assert file =~ ~S|broadcast socket, "shout", payload|
        assert file =~ ~S|{:noreply, socket}|
      end

      assert_file "test/web/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.RoomChannelTest|
        assert file =~ ~S|use Phoenix.ChannelCase|
        assert file =~ ~S|alias Phoenix.RoomChannel|

        assert file =~ ~S|test "ping replies with status ok"|
        assert file =~ ~S|ref = push socket, "ping", %{"hello" => "there"}|
        assert file =~ ~S|assert_reply ref, :ok, %{"hello" => "there"}|

        assert file =~ ~S|test "shout broadcasts to room:lobby"|
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
      Gen.Channel.run ["Admin.Room"]

      assert_file "lib/web/channels/admin/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Admin.RoomChannel do|
        assert file =~ ~S|use Phoenix.Web, :channel|
      end

      assert_file "test/web/channels/admin/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.Admin.RoomChannelTest|
        assert file =~ ~S|use Phoenix.ChannelCase|
        assert file =~ ~S|alias Phoenix.Admin.RoomChannel|
      end
    end
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Channel.run []
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Channel.run ["Admin.Room", "new_message"]
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/Dup2Channel is already taken/, fn ->
      Gen.Channel.run ["Dup2"]
    end
  end
end
