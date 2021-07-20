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
      end)

      assert_file("assets/js/user_socket.js", fn file ->
        assert file =~ ~S|and connect at the socket path in "lib/phoenix_web/endpoint.ex"|
        assert file =~ ~S|In your "lib/phoenix_web/router.ex":|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info, ["""

      Add the socket handler to your `lib/phoenix_web/endpoint.ex`, for example:

          socket "/socket", PhoenixWeb.UserSocket,
            websocket: true,
            longpoll: false

      After that you can define your `channel` topic in the newly created socket file.
      In order to create new channel files, you can use channel generator:

          mix phx.gen.channel Room

      For the front-end integration, you need to import the `user_socket.js`
      in your `app.js` file:

          import "./user_socket.js"
      """]}
  end

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project("generates channels", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Socket.run(["room"])

      assert_file("lib/phoenix/channels/room_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.RoomSocket do|
      end)

      assert_file("assets/js/room_socket.js", fn file ->
        assert file =~ ~S|and connect at the socket path in "lib/phoenix/endpoint.ex"|
        assert file =~ ~S|In your "lib/phoenix/router.ex":|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info, ["""

      Add the socket handler to your `lib/phoenix/endpoint.ex`, for example:

          socket "/socket", PhoenixWeb.RoomSocket,
            websocket: true,
            longpoll: false

      After that you can define your `channel` topic in the newly created socket file.
      In order to create new channel files, you can use channel generator:

          mix phx.gen.channel Room

      For the front-end integration, you need to import the `room_socket.js`
      in your `app.js` file:

          import "./room_socket.js"
      """]}
  end

  test "generates nested socket" do
    in_tmp_project("generates nested socket", fn ->
      Gen.Socket.run(["Admin.User"])

      assert_file("lib/phoenix_web/channels/admin/user_socket.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.UserSocket do|
      end)

      assert_file("assets/js/admin/user_socket.js", fn file ->
        assert file =~ ~S|and connect at the socket path in "lib/phoenix_web/endpoint.ex"|
        assert file =~ ~S|In your "lib/phoenix_web/router.ex":|

        assert file =~ ~S|let channel = socket.channel("room:42", {})|
        assert file =~ ~S|channel.join()|
      end)
    end)

    assert_received {:mix_shell, :info, ["""

      Add the socket handler to your `lib/phoenix_web/endpoint.ex`, for example:

          socket "/socket", PhoenixWeb.Admin.UserSocket,
            websocket: true,
            longpoll: false

      After that you can define your `channel` topic in the newly created socket file.
      In order to create new channel files, you can use channel generator:

          mix phx.gen.channel Room

      For the front-end integration, you need to import the `admin/user_socket.js`
      in your `app.js` file:

          import "./admin/user_socket.js"
      """]}
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Socket.run([])
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
