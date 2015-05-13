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
        assert file =~ "defmodule Phoenix.RoomChannel do"
        assert file =~ "use Phoenix.Web, :channel"
        assert file =~ "def join(\"rooms:lobby\", payload, socket) do"
        assert file =~ "def handle_in(\"ping\", payload, socket) do"
        assert file =~ "{:reply, {\"pong\", payload}, socket}"
        assert file =~ "def handle_in(\"shout\", payload, socket) do"
        assert file =~ "broadcast socket, \"shout\", payload"
        assert file =~ "{:noreply, socket}"
        assert file =~ "def handle_out(event, payload, socket) do"
        assert file =~ "push socket, event, payload"
      end

      assert_file "test/channels/room_channel_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.RoomChannelTest"
        assert file =~ "import Phoenix.Channel.ChannelTest"

        assert file =~ "build_socket(\"rooms:lobby\")"
        assert file =~ "|> join(RoomChannel)"
        assert file =~ "assert status == :ok"
      end
    end
  end

  test "generates nested channel" do
    in_tmp "generates nested channel", fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Admin.Room", "rooms"]

      assert_file "web/channels/admin/room_channel.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.RoomChannel do"
        assert file =~ "use Phoenix.Web, :channel"
      end
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Channel.run ["Admin.Room", "rooms", "new_message"]
    end
  end
end
