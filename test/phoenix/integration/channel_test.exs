Code.require_file "websocket_client.exs", __DIR__

defmodule Phoenix.Integration.ChannelTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Phoenix.Integration.ChannelTest.Router
  alias Phoenix.Integration.ChannelTest.RoomChannel
  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Socket.Message

  @port 4808
  Application.put_env(:phoenix, Router, http: [port: @port], https: false)

  defmodule Router do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"
    channel "rooms", RoomChannel
  end

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(socket, "lobby", message) do
      reply socket, "join", %{status: "connected"}
      broadcast socket, "user:entered", %{user: message["user"]}
      {:ok, socket}
    end

    def leave(socket, _message) do
      reply socket, "you:left", %{message: "bye!"}
      socket
    end

    def event(socket, "new:msg", message) do
      broadcast socket, "new:msg", message
      socket
    end
  end

  setup_all do
    capture_io fn -> Router.start end
    on_exit fn -> capture_io &Router.stop/0 end
    :ok
  end

  test "adapter handles websocket join, leave, and event messages" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    WebsocketClient.join(sock, "rooms", "lobby", %{})
    assert_receive %Message{event: "join", message: %{"status" => "connected"}}

    WebsocketClient.send_event(sock, "rooms", "lobby", "new:msg", %{body: "hi!"})
    assert_receive %Message{event: "new:msg", message: %{"body" => "hi!"}}

    WebsocketClient.leave(sock, "rooms", "lobby", %{})
    assert_receive %Message{event: "you:left", message: %{"message" => "bye!"}}

    WebsocketClient.send_event(sock, "rooms", "lobby", "new:msg", %{body: "hi!"})
    refute_receive %Message{}
  end

  test "adapter handles refuses websocket events that haven't joined" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    WebsocketClient.send_event(sock, "rooms", "lobby", "new:msg", %{body: "hi!"})
    refute_receive %Message{}
  end
end
