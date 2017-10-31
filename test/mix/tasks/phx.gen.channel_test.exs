Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule PhoenixWeb.DupChannel do
end

defmodule Mix.Tasks.Phx.Gen.ChannelTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates channel" do
    in_tmp_project "generates channel", fn ->
      Gen.Channel.run ["Room"]

      assert_file "lib/phoenix_web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
        assert file =~ ~S|def join("room:lobby", payload, socket) do|

        assert file =~ ~S|def handle_in("ping", payload, socket) do|
        assert file =~ ~S|{:reply, {:ok, payload}, socket}|
        assert file =~ ~S|def handle_in("shout", payload, socket) do|
        assert file =~ ~S|broadcast socket, "shout", payload|
        assert file =~ ~S|{:noreply, socket}|
      end

      assert_file "test/phoenix_web/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
        assert file =~ ~S|alias PhoenixWeb.RoomChannel|

        assert file =~ ~S|subscribe_and_join(RoomChannel|

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

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project "generates channels", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Channel.run ["room"]
      assert_file "lib/phoenix/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end

      assert_file "test/phoenix/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|alias PhoenixWeb.RoomChannel|
      end
    end
  end

  test "generates nested channel" do
    in_tmp_project "generates nested channel", fn ->
      Gen.Channel.run ["Admin.Room"]

      assert_file "lib/phoenix_web/channels/admin/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end

      assert_file "test/phoenix_web/channels/admin/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
        assert file =~ ~S|alias PhoenixWeb.Admin.RoomChannel|
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
    assert_raise Mix.Error, ~r/DupChannel is already taken/, fn ->
      Gen.Channel.run ["Dup"]
    end
  end
end
