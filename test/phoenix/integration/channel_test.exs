Code.require_file "websocket_client.exs", __DIR__
Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.ChannelTest do
  use ExUnit.Case, async: false
  use RouterHelper
  import Plug.Conn, except: [assign: 3]

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Broadcast
  alias __MODULE__.Endpoint

  @port 5807
  @ensure_window_timeout_ms 500

  Application.put_env(:channel_app, Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    debug_errors: false,
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: :int_pub]
  ])

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(topic, message, socket) do
      Process.flag(:trap_exit, true)
      Process.register(self, String.to_atom(topic))
      send(self, {:after_join, message})
      {:ok, socket}
    end

    def handle_info({:after_join, message}, socket) do
      broadcast socket, "user:entered", %{user: message["user"]}
      push socket, "joined", Map.merge(%{status: "connected"}, socket.assigns)
      {:noreply, socket}
    end

    def handle_in("new:msg", message, socket) do
      broadcast! socket, "new:msg", message
      {:noreply, socket}
    end

    def handle_in("boom", _message, _socket) do
      raise "boom"
    end

    def terminate(_reason, socket) do
      push socket, "you:left", %{message: "bye!"}
      :ok
    end
  end

  defmodule Router do
    use Phoenix.Router
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "rooms:*", RoomChannel

    transport :longpoll, Phoenix.Transports.LongPoll,
      window_ms: 200,
      origins: ["//example.com"]

    transport :websocket, Phoenix.Transports.WebSocket,
      origins: ["//example.com"]

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
    use Phoenix.Endpoint, otp_app: :channel_app

    def call(conn, opts) do
      Logger.disable(self)
      super(conn, opts)
    end

    socket "/ws", UserSocket
    socket "/ws/admin", UserSocket

    plug Plug.Parsers,
      parsers: [:urlencoded, :json],
      pass: "*/*",
      json_decoder: Poison

    plug Plug.Session,
      store: :cookie,
      key: "_integration_test",
      encryption_salt: "yadayada",
      signing_salt: "yadayada"

    plug Router
  end


  setup_all do
    capture_log fn -> Endpoint.start_link() end
    :ok
  end

  test "endpoint handles mulitple mount segments" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/admin/websocket")
    WebsocketClient.join(sock, "rooms:admin-lobby", %{})
    assert_receive %Message{event: "phx_reply",
                            payload: %{"response" => %{}, "status" => "ok"},
                            ref: "1", topic: "rooms:admin-lobby"}
  end


  ## Websocket Transport

  test "adapter handles websocket join, leave, and event messages" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.join(sock, "rooms:lobby1", %{})
    assert_receive %Message{event: "phx_reply",
                            payload: %{"response" => %{}, "status" => "ok"},
                            ref: "1", topic: "rooms:lobby1"}

    assert_receive %Message{event: "joined", payload: %{"status" => "connected",
                                                        "user_id" => nil}}
    assert_receive %Message{event: "user:entered",
                            payload: %{"user" => nil},
                            ref: nil, topic: "rooms:lobby1"}
    channel_pid = Process.whereis(:"rooms:lobby1")
    assert channel_pid
    assert Process.alive?(channel_pid)

    WebsocketClient.send_event(sock, "rooms:lobby1", "new:msg", %{body: "hi!"})
    assert_receive %Message{event: "new:msg", payload: %{"body" => "hi!"}}

    WebsocketClient.leave(sock, "rooms:lobby1", %{})
    assert_receive %Message{event: "you:left", payload: %{"message" => "bye!"}}
    assert_receive %Message{event: "phx_reply", payload: %{"status" => "ok"}}
    assert_receive %Message{event: "phx_close", payload: %{}}
    refute Process.alive?(channel_pid)

    WebsocketClient.send_event(sock, "rooms:lobby1", "new:msg", %{body: "Should ignore"})
    refute_receive %Message{}
  end

  test "websocket adapter sends phx_error if a channel server abnormally exits" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.join(sock, "rooms:lobby", %{})
    assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    assert_receive %Message{event: "joined"}
    assert_receive %Message{event: "user:entered"}

    WebsocketClient.send_event(sock, "rooms:lobby", "boom", %{})
    assert_receive %Message{event: "phx_error", payload: %{}, topic: "rooms:lobby"}
  end

  test "websocket channels are terminated if transport normally exits" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.join(sock, "rooms:lobby2", %{})
    assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    assert_receive %Message{event: "joined"}
    channel = Process.whereis(:"rooms:lobby2")
    assert channel
    Process.monitor(channel)
    WebsocketClient.close(sock)

    assert_receive {:DOWN, _, :process, ^channel, :shutdown}
  end

  test "adapter handles refuses websocket events that haven't joined" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket")

    WebsocketClient.send_event(sock, "rooms:lobby", "new:msg", %{body: "hi!"})
    refute_receive %Message{}
  end

  test "websocket refuses unallowed origins" do
    assert {:ok, _} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket",
                                                 [{"origin", "https://example.com"}])
    refute {:ok, _} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket",
                                                 [{"origin", "http://notallowed.com"}])
  end

  test "websocket refuses UserSocket connects that error with 403 response" do
    assert WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket?reject=true") ==
      {:error, {403, "Forbidden"}}
  end

  test "websocket shuts down when receiving disconnect broadcasts on socket's id" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws/websocket?user_id=1001")
    WebsocketClient.join(sock, "rooms:wsdisconnect1", %{})
    assert_receive %Message{topic: "rooms:wsdisconnect1", event: "phx_reply",
                            ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
    WebsocketClient.join(sock, "rooms:wsdisconnect2", %{})
    assert_receive %Message{topic: "rooms:wsdisconnect2", event: "phx_reply",
                            ref: "2", payload: %{"response" => %{}, "status" => "ok"}}
    chan1 = Process.whereis(:"rooms:wsdisconnect1")
    assert chan1
    chan2 = Process.whereis(:"rooms:wsdisconnect2")
    assert chan2
    Process.monitor(sock)
    Process.monitor(chan1)
    Process.monitor(chan2)

    Endpoint.broadcast("user_sockets:1001", "disconnect", %{})

    assert_receive {:DOWN, _, :process, ^sock, :normal}
    assert_receive {:DOWN, _, :process, ^chan1, :shutdown}
    assert_receive {:DOWN, _, :process, ^chan2, :shutdown}
  end


  ## Longpoller Transport

  @doc """
  Helper method to maintain token session state when making HTTP requests.

  Returns a response with body decoded into JSON map.
  """
  def poll(method, path, params, json \\ nil, headers \\ %{}) do
    headers = Map.merge(%{"content-type" => "application/json"}, headers)
    body = Poison.encode!(json)
    url = "http://127.0.0.1:#{@port}#{path}/longpoll?" <> URI.encode_query(params)

    {:ok, resp} = HTTPClient.request(method, url, headers, body)

    if resp.body != "" do
      put_in resp.body, Poison.decode!(resp.body)
    else
      resp
    end
  end

  test "adapter handles longpolling join, leave, and event messages" do
    # create session
    resp = poll :get, "/ws", %{}, %{}
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["token"]
    assert resp.body["sig"]
    assert resp.body["status"] == 410
    assert resp.status == 200

    # join
    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_join",
      "ref" => "123",
      "payload" => %{}
    }
    assert resp.body["status"] == 200

    # poll with messsages sends buffer
    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 200

    [status_msg, phx_reply, user_entered] = Enum.sort(resp.body["messages"])
    assert phx_reply ==
      %{"event" => "phx_reply",
        "payload" => %{"response" => %{}, "status" => "ok"},
        "ref" => "123", "topic" => "rooms:lobby"}
    assert status_msg ==
      %{"event" => "joined",
        "payload" => %{"status" => "connected", "user_id" => nil},
        "ref" => nil, "topic" => "rooms:lobby"}
    assert user_entered ==
      %{"event" => "user:entered",
        "payload" => %{"user" => nil},
        "ref" => nil, "topic" => "rooms:lobby"}

    # poll without messages sends 204 no_content
    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 204

    # messages are buffered between polls
    Endpoint.broadcast! "rooms:lobby", "user:entered", %{name: "José"}
    Endpoint.broadcast! "rooms:lobby", "user:entered", %{name: "Sonny"}
    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 200
    assert Enum.count(resp.body["messages"]) == 2
    assert Enum.map(resp.body["messages"], &(&1["payload"]["name"])) == ["José", "Sonny"]

    # poll without messages sends 204 no_content
    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 204

    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 204

    # generic events
    Phoenix.PubSub.subscribe(:int_pub, self, "rooms:lobby")
    resp = poll :post, "/ws", Map.take(resp.body, ["token", "sig"]), %{
      "topic" => "rooms:lobby",
      "event" => "new:msg",
      "ref" => "123",
      "payload" => %{"body" => "hi!"}
    }
    assert resp.body["status"] == 200
    assert_receive %Broadcast{event: "new:msg", payload: %{"body" => "hi!"}}
    resp = poll(:get, "/ws", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 200

    # unauthorized events
    capture_log fn ->
      Phoenix.PubSub.subscribe(:int_pub, self, "rooms:private-room")
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:private-room",
        "event" => "new:msg",
        "ref" => "123",
        "payload" => %{"body" => "this method shouldn't send!'"}
      }
      assert resp.body["status"] == 401
      refute_receive %Broadcast{event: "new:msg"}


      ## multiplexed sockets

      # join
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:room123",
        "event" => "phx_join",
        "ref" => "123",
        "payload" => %{}
      }
      assert resp.body["status"] == 200
      Endpoint.broadcast! "rooms:lobby", "new:msg", %{body: "Hello lobby"}
      # poll
      resp = poll(:get, "/ws", session)
      session = Map.take(resp.body, ["token", "sig"])
      assert resp.body["status"] == 200
      assert Enum.sort(resp.body["messages"]) == Enum.sort([
        %{"event" => "joined", "payload" => %{"status" => "connected", "user_id" => nil}, "ref" => nil, "topic" => "rooms:room123"},
        %{"event" => "new:msg", "payload" => %{"body" => "Hello lobby"}, "ref" => nil, "topic" => "rooms:lobby"},
        %{"event" => "phx_reply", "payload" => %{"response" => %{}, "status" => "ok"}, "ref" => "123", "topic" => "rooms:room123"},
        %{"event" => "user:entered", "payload" => %{"user" => nil}, "ref" => nil, "topic" => "rooms:room123"}])

      channel = Process.whereis(:"rooms:room123")
      assert channel
      Process.monitor(channel)

      ## Server termination handling

      # 410 from crashed/terminated longpoller server when polling
      :timer.sleep @ensure_window_timeout_ms
      resp = poll(:get, "/ws", session)
      session = Map.take(resp.body, ["token", "sig"])
      assert resp.body["status"] == 410
      # shutdowns terminate the channels
      assert_receive {:DOWN, _, :process, ^channel, {:shutdown, _}}

      # join
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:lobby",
        "event" => "phx_join",
        "ref" => "123",
        "payload" => %{}
      }
      assert resp.body["status"] == 200
      Phoenix.PubSub.subscribe(:int_pub, self, "rooms:lobby")
      :timer.sleep @ensure_window_timeout_ms
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:lobby",
        "event" => "new:msg",
        "ref" => "123",
        "payload" => %{"body" => "hi!"}
      }
      assert resp.body["status"] == 410
      refute_receive %Message{event: "new:msg", payload: %{"body" => "hi!"}}

      # 410 from crashed/terminated longpoller server when publishing
      # create new session
      resp = poll :post, "/ws", %{"token" => "foo", "sig" => "bar"}, %{}
      assert resp.body["status"] == 410
    end
  end

  test "longpoller refuses unallowed origins" do
    resp = poll(:get, "/ws", %{}, nil, %{"origin" => "https://example.com"})
    assert resp.body["status"] == 410

    resp = poll(:get, "/ws", %{}, nil, %{"origin" => "http://notallowed.com"})
    assert resp.body["status"] == 403
  end

  test "longpoller adapter sends phx_error if a channel server abnormally exits" do
    # create session
    resp = poll :get, "/ws", %{}, %{}
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 410
    assert resp.status == 200
    # join
    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_join",
      "ref" => "123",
      "payload" => %{}
    }
    assert resp.body["status"] == 200
    assert resp.status == 200
    # poll
    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "boom",
      "ref" => "123",
      "payload" => %{}
    }
    assert resp.body["status"] == 200
    assert resp.status == 200

    resp = poll(:get, "/ws", session)

    [_phx_reply, _joined, _user_entered, _you_left_msg, chan_error] = resp.body["messages"]

    assert chan_error ==
      %{"event" => "phx_error", "payload" => %{}, "topic" => "rooms:lobby", "ref" => nil}
  end

  test "longpoller adapter sends phx_close if a channel server normally exits" do
    # create session
    resp = poll :get, "/ws", %{"user_id" => "123"}, %{}
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["status"] == 410
    assert resp.status == 200
    # join
    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_join",
      "ref" => "1",
      "payload" => %{}
    }
    assert resp.body["status"] == 200
    assert resp.status == 200

    # poll
    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_leave",
      "ref" => "2",
      "payload" => %{}
    }
    assert resp.body["status"] == 200
    assert resp.status == 200

    # leave
    resp = poll(:get, "/ws", session)
    assert Enum.sort(resp.body["messages"]) == Enum.sort([
      %{"event" => "phx_reply", "payload" => %{"response" => %{}, "status" => "ok"}, "ref" => "1", "topic" => "rooms:lobby"},
      %{"event" => "user:entered", "payload" => %{"user" => nil}, "ref" => nil, "topic" => "rooms:lobby"},
      %{"event" => "joined", "payload" => %{"status" => "connected", "user_id" => "123"}, "ref" => nil, "topic" => "rooms:lobby"},
      %{"event" => "phx_reply", "payload" => %{"response" => %{}, "status" => "ok"}, "ref" => "2", "topic" => "rooms:lobby"},
      %{"event" => "you:left", "payload" => %{"message" => "bye!"}, "ref" => nil, "topic" => "rooms:lobby"},
      %{"event" => "phx_close", "payload" => %{}, "ref" => nil, "topic" => "rooms:lobby"}
    ])
  end

  test "longpoller refuses UserSocket connects that error with 403 response" do
    resp = poll :get, "/ws", %{"reject" => "true"}, %{}
    assert resp.body["status"] == 403
  end

  test "longpoller shuts down when receiving disconnect broadcasts on socket's id" do
    # create session
    resp = poll :get, "/ws", %{"user_id" => "456"}, %{}
    session = Map.take(resp.body, ["token", "sig"])
    # join
    poll :post, "/ws", session, %{
      "topic" => "rooms:lpdisconnect1",
      "event" => "phx_join",
      "ref" => "1",
      "payload" => %{}
    }
    # join
    poll :post, "/ws", session, %{
      "topic" => "rooms:lpdisconnect2",
      "event" => "phx_join",
      "ref" => "1",
      "payload" => %{}
    }
    chan1 = Process.whereis(:"rooms:lpdisconnect1")
    assert chan1
    chan2 = Process.whereis(:"rooms:lpdisconnect2")
    assert chan2
    Process.monitor(chan1)
    Process.monitor(chan2)

    Endpoint.broadcast("user_sockets:456", "disconnect", %{})

    assert_receive {:DOWN, _, :process, ^chan1, {:shutdown, :disconnected}}
    assert_receive {:DOWN, _, :process, ^chan2, {:shutdown, :disconnected}}

    poll(:get, "/ws", session)
    assert resp.body["status"] == 410
  end
end
