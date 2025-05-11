Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule PhoenixWeb.DupSocket do
end

defmodule Mix.Tasks.Phx.Gen.SocketTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates socket" do
    in_tmp_project("generates socket", fn ->
      Gen.Socket.run(["User"])

      assert_file("lib/phoenix_web/channels/user_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.UserSocket do|

        assert file =~ ~S|# Uncomment the following line to define a "room:*" topic|
        assert file =~ ~S|# pointing to the `PhoenixWeb.RoomChannel`:|
        assert file =~ ~S|# channel "room:*", PhoenixWeb.RoomChannel|

        assert file =~ ~S|def connect(_params, socket, _connect_info) do|
        assert file =~ ~S|def id(_socket), do: nil|
      end)

      assert_file("assets/js/user_socket.js", fn file ->
        assert file =~ ~S|// NOTE: The contents of this file will only be executed if|
        assert file =~ ~S|// you uncomment its entry in "assets/js/app.js".|

        assert file =~ ~S|// And connect to the path in "lib/phoenix_web/endpoint.ex".|
        assert file =~ ~S|let socket = new Socket("/socket", {authToken: window.userToken})|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nAdd the socket handler to your `lib/phoenix_web/endpoint.ex`" <> _]}
  end

  test "generates socket with channel declaration" do
    in_tmp_project("generates socket with channel declaration", fn ->
      Gen.Socket.run(~w(User --from-channel Chat))

      assert_file("lib/phoenix_web/channels/user_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.UserSocket do|

        refute file =~ ~S|# Uncomment the following line to define a "room:*" topic|
        assert file =~ ~S|channel "chat:*", PhoenixWeb.ChatChannel|
      end)
    end)
  end

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project("generates channels", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Socket.run(["Room"])

      assert_file("lib/phoenix/channels/room_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomSocket do|
      end)

      assert_file("assets/js/room_socket.js", fn file ->
        assert file =~ ~S|// NOTE: The contents of this file will only be executed if|
        assert file =~ ~S|// you uncomment its entry in "assets/js/app.js".|

        assert file =~ ~S|// Bring in Phoenix channels client library:|
        assert file =~ ~S|import {Socket} from "phoenix"|

        assert file =~ ~S|// And connect to the path in "lib/phoenix/endpoint.ex".|

        assert file =~
                 ~S|Read the [`Using Token Authentication`](https://hexdocs.pm/phoenix/channels.html#using-token-authentication)|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nAdd the socket handler to your `lib/phoenix/endpoint.ex`" <> _]}
  end

  test "generates nested socket" do
    in_tmp_project("generates nested socket", fn ->
      Gen.Socket.run(["Admin.User"])

      assert_file("lib/phoenix_web/channels/admin/user_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.UserSocket do|
      end)

      assert_file("assets/js/admin/user_socket.js", fn file ->
        assert file =~ ~S|// NOTE: The contents of this file will only be executed if|
        assert file =~ ~S|// you uncomment its entry in "assets/js/app.js".|

        assert file =~ ~S|// Bring in Phoenix channels client library:|
        assert file =~ ~S|import {Socket} from "phoenix"|

        assert file =~ ~S|// And connect to the path in "lib/phoenix_web/endpoint.ex".|
        assert file =~ ~S|let socket = new Socket("/socket", {authToken: window.userToken})|

        assert file =~
                 ~S|Read the [`Using Token Authentication`](https://hexdocs.pm/phoenix/channels.html#using-token-authentication)|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info,
                     ["\nAdd the socket handler to your `lib/phoenix_web/endpoint.ex`" <> _]}
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Socket.run([])
    end
  end

  test "passing invalid name raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Socket.run(["room"])
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Socket.run(["Admin.User", "new_message"])
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/DupSocket is already taken/, fn ->
      Gen.Socket.run(["Dup"])
    end
  end
end
