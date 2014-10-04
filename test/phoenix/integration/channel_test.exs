Code.require_file "channel_client.exs", __DIR__

defmodule Phoenix.Integration.ChannelTest do
  use ExUnit.Case, async: true
  alias Phoenix.Integration.ChannelTest.Router
  alias Phoenix.Integration.ChannelTest.RoomChannel
  alias Phoenix.Integration.ChannelClient
  alias Phoenix.Socket.Message

  @port 4808

  Application.put_env(:phoenix, Router, port: @port)

  setup_all do
    Router.start
    on_exit &Router.stop/0
    :ok
  end

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

  test "adapter handles websocket join, leave, and event messages" do
    {:ok, sock} = ChannelClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    ChannelClient.join(sock, "rooms", "lobby", %{})
    assert_receive %Message{event: "join", message: %{"status" => "connected"}}

    ChannelClient.send_event(sock, "rooms", "lobby", "new:msg", %{body: "hi!"})
    assert_receive %Message{event: "new:msg", message: %{"body" => "hi!"}}

    ChannelClient.leave(sock, "rooms", "lobby", %{})
    assert_receive %Message{event: "you:left", message: %{"message" => "bye!"}}
  end

  test "adapter handles refuses websocket events that haven't joined" do
    {:ok, sock} = ChannelClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    ChannelClient.send_event(sock, "rooms", "lobby", "new:msg", %{body: "hi!"})
    refute_receive %Message{}
  end
end
