Code.require_file "../../support/websocket_client.exs", __DIR__

defmodule Phoenix.Integration.WebSocketTest do
  # TODO: Make this test async
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Socket.Message
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5807

  Application.put_env(:phoenix, Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    debug_errors: false,
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__]
  ])

  defmodule RoomChannel do
    use Phoenix.Channel

    intercept ["new_msg"]

    def join(topic, message, socket) do
      Process.register(self(), String.to_atom(topic))
      send(self(), {:after_join, message})
      {:ok, socket}
    end

    def handle_info({:after_join, message}, socket) do
      broadcast socket, "user_entered", %{user: message["user"]}
      push socket, "joined", Map.merge(%{status: "connected"}, socket.assigns)
      {:noreply, socket}
    end

    def handle_in("new_msg", message, socket) do
      broadcast! socket, "new_msg", message
      {:reply, :ok, socket}
    end

    def handle_in("boom", _message, _socket) do
      raise "boom"
    end

    def handle_out("new_msg", payload, socket) do
      push socket, "new_msg", Map.put(payload, "transport", inspect(socket.transport))
      {:noreply, socket}
    end

    def terminate(_reason, socket) do
      push socket, "you_left", %{message: "bye!"}
      :ok
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

    transport :websocket, Phoenix.Transports.WebSocket,
      check_origin: ["//example.com"], timeout: 200

    def connect(%{"reject" => "true"}, _socket) do
      :error
    end

    def connect(params, socket) do
      Logger.disable(self())
      {:ok, assign(socket, :user_id, params["user_id"])}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end
  end

  defmodule LoggingSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

    transport :websocket, Phoenix.Transports.WebSocket,
      check_origin: ["//example.com"], timeout: 200

    def connect(%{"reject" => "true"}, _socket) do
      :error
    end

    def connect(params, socket) do
      {:ok, assign(socket, :user_id, params["user_id"])}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket
    socket "/ws/admin", UserSocket
    socket "/ws/logging", LoggingSocket
  end

  setup_all do
    capture_log fn -> Endpoint.start_link() end
    :ok
  end

  test "endpoint handles multiple mount segments" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/admin/websocket")
    WebsocketClient.join(sock, "room:admin-lobby", %{})
    assert_receive %Message{event: "phx_reply",
                            payload: %{"response" => %{}, "status" => "ok"},
                            ref: "1", topic: "room:admin-lobby"}
  end

  test "join, leave, and event messages" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket")
    WebsocketClient.join(sock, "room:lobby1", %{})

    assert_receive %Message{event: "phx_reply",
                            payload: %{"response" => %{}, "status" => "ok"},
                            ref: "1", topic: "room:lobby1"}

    assert_receive %Message{event: "joined", payload: %{"status" => "connected",
                                                        "user_id" => nil}}
    assert_receive %Message{event: "user_entered",
                            payload: %{"user" => nil},
                            ref: nil, topic: "room:lobby1"}

    channel_pid = Process.whereis(:"room:lobby1")
    assert channel_pid
    assert Process.alive?(channel_pid)

    WebsocketClient.send_event(sock, "room:lobby1", "new_msg", %{body: "hi!"})
    assert_receive %Message{event: "new_msg", payload: %{"transport" => "Phoenix.Transports.WebSocket", "body" => "hi!"}}

    WebsocketClient.leave(sock, "room:lobby1", %{})
    assert_receive %Message{event: "you_left", payload: %{"message" => "bye!"}}
    assert_receive %Message{event: "phx_reply", payload: %{"status" => "ok"}}
    assert_receive %Message{event: "phx_close", payload: %{}}
    refute Process.alive?(channel_pid)

    WebsocketClient.send_event(sock, "room:lobby1", "new_msg", %{body: "Should ignore"})
    refute_receive %Message{event: "new_msg"}
    assert_receive %Message{event: "phx_reply", payload: %{"response" => %{"reason" => "unmatched topic"}}}

    WebsocketClient.send_event(sock, "room:lobby1", "new_msg", %{body: "Should ignore"})
    refute_receive %Message{event: "new_msg"}
  end

  test "logs and filter params on join and handle_in" do
    topic = "room:admin-lobby"

    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/logging/websocket")
    log = capture_log fn ->
      WebsocketClient.join(sock, topic, %{"join" => "yes", "password" => "no"})
      assert_receive %Message{event: "phx_reply",
                              payload: %{"response" => %{}, "status" => "ok"},
                              ref: "1", topic: "room:admin-lobby"}
    end
    assert log =~ "Parameters: %{\"join\" => \"yes\", \"password\" => \"[FILTERED]\"}"

    log = capture_log fn ->
      WebsocketClient.send_event(sock, topic, "new_msg", %{"in" => "yes", "password" => "no"})
      assert_receive %Message{event: "phx_reply", ref: "2"}
    end
    assert log =~ "Parameters: %{\"in\" => \"yes\", \"password\" => \"[FILTERED]\"}"
  end

  test "sends phx_error if a channel server abnormally exits" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.join(sock, "room:lobby", %{})
    assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    assert_receive %Message{event: "joined"}
    assert_receive %Message{event: "user_entered"}

    capture_log fn ->
      WebsocketClient.send_event(sock, "room:lobby", "boom", %{})
      assert_receive %Message{event: "phx_error", payload: %{}, topic: "room:lobby"}
    end
  end

  test "channels are terminated if transport normally exits" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.join(sock, "room:lobby2", %{})
    assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    assert_receive %Message{event: "joined"}
    channel = Process.whereis(:"room:lobby2")
    assert channel
    Process.monitor(channel)
    WebsocketClient.close(sock)

    assert_receive {:DOWN, _, :process, ^channel, {:shutdown, :closed}}
  end

  test "refuses websocket events that haven't joined" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.send_event(sock, "room:lobby", "new_msg", %{body: "hi!"})
    refute_receive %Message{event: "new_msg"}
    assert_receive %Message{event: "phx_reply", payload: %{"response" => %{"reason" => "unmatched topic"}}}

    WebsocketClient.send_event(sock, "room:lobby1", "new_msg", %{body: "Should ignore"})
    refute_receive %Message{event: "new_msg"}
 end

  test "refuses unallowed origins" do
    capture_log fn ->
      assert {:ok, _} =
        WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket",
                                          [{"origin", "https://example.com"}])
      assert {:error, {403, _}} =
        WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket",
                                         [{"origin", "http://notallowed.com"}])
    end
  end

  test "refuses connects that error with 403 response" do
    assert WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket?reject=true") ==
           {:error, {403, "Forbidden"}}
  end

  test "shuts down when receiving disconnect broadcasts on socket's id" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket?user_id=1001")

    WebsocketClient.join(sock, "room:wsdisconnect1", %{})
    assert_receive %Message{topic: "room:wsdisconnect1", event: "phx_reply",
                            ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    WebsocketClient.join(sock, "room:wsdisconnect2", %{})
    assert_receive %Message{topic: "room:wsdisconnect2", event: "phx_reply",
                            ref: "2", payload: %{"response" => %{}, "status" => "ok"}}

    chan1 = Process.whereis(:"room:wsdisconnect1")
    assert chan1
    chan2 = Process.whereis(:"room:wsdisconnect2")
    assert chan2
    Process.monitor(sock)
    Process.monitor(chan1)
    Process.monitor(chan2)

    Endpoint.broadcast("user_sockets:1001", "disconnect", %{})

    assert_receive {:DOWN, _, :process, ^sock, :normal}
    assert_receive {:DOWN, _, :process, ^chan1, :shutdown}
    assert_receive {:DOWN, _, :process, ^chan2, :shutdown}
  end

  test "duplicate join event closes existing channel" do
    {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket?user_id=1001")
    WebsocketClient.join(sock, "room:joiner", %{})
    assert_receive %Message{topic: "room:joiner", event: "phx_reply",
                            ref: "1", payload: %{"response" => %{}, "status" => "ok"}}

    WebsocketClient.join(sock, "room:joiner", %{})
    assert_receive %Message{topic: "room:joiner", event: "phx_reply",
                            ref: "2", payload: %{"response" => %{}, "status" => "ok"}}

    assert_receive %Message{topic: "room:joiner", event: "phx_close",
                            ref: "1", payload: %{}}
  end

  test "returns 403 when versions to not match" do
    log = capture_log fn ->
      url = "ws://127.0.0.1:#{@port}/ws/websocket?vsn=123.1.1"
      assert WebsocketClient.start_link(self(), url) ==
             {:error, {403, "Forbidden"}}
    end
    assert log =~ "The client's requested channel transport version \"123.1.1\" does not match server's version"
  end

  test "shuts down if client goes quiet" do
    {:ok, socket} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/websocket")
    Process.monitor(socket)
    WebsocketClient.send_heartbeat(socket)
    assert_receive %Message{event: "phx_reply",
                            payload: %{"response" => %{}, "status" => "ok"},
                            ref: "1", topic: "phoenix"}

    assert_receive {:DOWN, _, :process, ^socket, :normal}, 400
  end
end
