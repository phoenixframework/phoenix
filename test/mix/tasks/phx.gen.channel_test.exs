Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule PhoenixWeb.DupChannel do
end

defmodule Ecto.Adapters.SQL do
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
    in_tmp_project("generates channel", fn ->
      # Ensure the `user_socket.ex` exists first.
      Gen.Socket.run(["User"])
      Gen.Channel.run(["Room"])

      assert_file("lib/phoenix_web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
        assert file =~ ~S|def join("room:lobby", payload, socket) do|

        assert file =~ ~S|def handle_in("ping", payload, socket) do|
        assert file =~ ~S|{:reply, {:ok, payload}, socket}|
        assert file =~ ~S|def handle_in("shout", payload, socket) do|
        assert file =~ ~S|broadcast(socket, "shout", payload)|
        assert file =~ ~S|{:noreply, socket}|
      end)

      assert_file("test/support/channel_case.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.ChannelCase|
        assert file =~ ~S|@endpoint PhoenixWeb.Endpoint|
        assert file =~ ~S|Phoenix.DataCase.setup_sandbox|
      end)

      assert_file("test/phoenix_web/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
        assert file =~ ~S|> socket("user_id", %{some: :assign}|
        assert file =~ ~S|> subscribe_and_join(PhoenixWeb.RoomChannel|

        assert file =~ ~S|test "ping replies with status ok"|
        assert file =~ ~S|ref = push(socket, "ping", %{"hello" => "there"})|
        assert file =~ ~S|assert_reply ref, :ok, %{"hello" => "there"}|

        assert file =~ ~S|test "shout broadcasts to room:lobby"|
        assert file =~ ~S|push(socket, "shout", %{"hello" => "all"})|
        assert file =~ ~S|assert_broadcast "shout", %{"hello" => "all"}|

        assert file =~ ~S|test "broadcasts are pushed to the client"|
        assert file =~ ~S|broadcast_from!(socket, "broadcast", %{"some" => "data"})|
        assert file =~ ~S|assert_push "broadcast", %{"some" => "data"}|
      end)
    end)

    assert_received {:mix_shell, :info,
                     [
                       """

                       Add the channel to your `lib/phoenix_web/channels/user_socket.ex` handler, for example:

                           channel "room:lobby", PhoenixWeb.RoomChannel
                       """
                     ]}
  end

  test "generates channel and ask to create UserSocket" do
    in_tmp_project("generates channel", fn ->
      # Accepts creation of the UserSocket
      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Channel.run(["Room"])

      assert_file("lib/phoenix_web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end)

      assert_file("test/phoenix_web/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
      end)

      assert_received {:mix_shell, :info,
                       [
                         "\nThe default socket handler - PhoenixWeb.UserSocket - was not found" <>
                           _
                       ]}

      assert_received {:mix_shell, :yes?, [question]}
      assert question =~ "Do you want to create it?"

      assert_received {:mix_shell, :info,
                       ["\nAdd the socket handler to your `lib/phoenix_web/endpoint.ex`" <> _]}

      assert_file("lib/phoenix_web/channels/user_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.UserSocket do|
        assert file =~ ~S|channel "room:*", PhoenixWeb.RoomChannel|
      end)
    end)
  end

  test "generates channel and give instructions when UserSocket does not exist" do
    in_tmp_project("generates channel", fn ->
      send(self(), {:mix_shell_input, :yes?, false})
      Gen.Channel.run(["Room"])

      assert_file("lib/phoenix_web/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end)

      assert_file("test/phoenix_web/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nThe default socket handler - PhoenixWeb.UserSocket - was not found" <> _]}

    assert_received {:mix_shell, :yes?, [question]}
    assert question =~ "Do you want to create it?"

    assert_received {:mix_shell, :info, ["\nTo create it, please run the mix task:" <> _]}
  end

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project("generates channels", fn ->
      send(self(), {:mix_shell_input, :yes?, false})
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Channel.run(["Room"])

      assert_file("lib/phoenix/channels/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end)

      assert_file("test/support/channel_case.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.ChannelCase|
        assert file =~ ~S|@endpoint PhoenixWeb.Endpoint|
        assert file =~ ~S|Phoenix.DataCase.setup_sandbox|
      end)

      assert_file("test/phoenix/channels/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomChannelTest|
        assert file =~ ~S|subscribe_and_join(PhoenixWeb.RoomChannel|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nThe default socket handler - PhoenixWeb.UserSocket - was not found" <> _]}

    assert_received {:mix_shell, :yes?, [question]}
    assert question =~ "Do you want to create it?"

    assert_received {:mix_shell, :info, ["\nTo create it, please run the mix task" <> _]}
  end

  test "generates nested channel" do
    in_tmp_project("generates nested channel", fn ->
      send(self(), {:mix_shell_input, :yes?, false})
      Gen.Channel.run(["Admin.Room"])

      assert_file("lib/phoenix_web/channels/admin/room_channel.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.RoomChannel do|
        assert file =~ ~S|use PhoenixWeb, :channel|
      end)

      assert_file("test/phoenix_web/channels/admin/room_channel_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.RoomChannelTest|
        assert file =~ ~S|use PhoenixWeb.ChannelCase|
        assert file =~ ~S|subscribe_and_join(PhoenixWeb.Admin.RoomChannel|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nThe default socket handler - PhoenixWeb.UserSocket - was not found" <> _]}

    assert_received {:mix_shell, :yes?, [question]}
    assert question =~ "Do you want to create it?"

    assert_received {:mix_shell, :info, ["\nTo create it, please run the mix task" <> _]}
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Channel.run([])
    end
  end

  test "passing invalid name raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Channel.run(["room"])
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Channel.run(["Admin.Room", "new_message"])
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/DupChannel is already taken/, fn ->
      Gen.Channel.run(["Dup"])
    end
  end
end
