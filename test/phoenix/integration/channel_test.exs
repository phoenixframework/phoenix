Code.require_file "websocket_client.exs", __DIR__
Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.ChannelTest do
  use ExUnit.Case, async: true
  import RouterHelper, only: [capture_log: 1]

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Socket.Message
  alias Phoenix.PubSub.PG2
  alias __MODULE__.Endpoint

  @port 5807
  @window_ms 100
  @pubsub_window_ms 100
  @ensure_window_timeout_ms @window_ms * 4

  Application.put_env(:channel_app, Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    debug_errors: false,
    transports: [longpoller_window_ms: @window_ms, longpoller_pubsub_timeout_ms: @pubsub_window_ms],
    server: true,
    pubsub: [adapter: PG2, name: :int_pub]
  ])

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(_topic, message, socket) do
      reply socket, "join", %{status: "connected"}
      broadcast socket, "user:entered", %{user: message["user"]}
      {:ok, socket}
    end

    def leave(_message, socket) do
      reply socket, "you:left", %{message: "bye!"}
    end

    def handle_in("new:msg", message, socket) do
      broadcast! socket, "new:msg", message
    end
  end

  defmodule Router do
    use Phoenix.Router

    def call(conn, opts) do
      Logger.disable(self)
      super(conn, opts)
    end

    socket "/ws" do
      channel "rooms:*", RoomChannel
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :channel_app

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
    capture_log fn -> Endpoint.start_link end
    :ok
  end

  ## Websocket Transport

  test "adapter handles websocket join, leave, and event messages" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    WebsocketClient.join(sock, "rooms:lobby", %{})
    assert_receive %Message{event: "join", payload: %{"status" => "connected"}}

    WebsocketClient.send_event(sock, "rooms:lobby", "new:msg", %{body: "hi!"})
    assert_receive %Message{event: "new:msg", payload: %{"body" => "hi!"}}

    WebsocketClient.leave(sock, "rooms:lobby", %{})
    assert_receive %Message{event: "you:left", payload: %{"message" => "bye!"}}

    WebsocketClient.send_event(sock, "rooms:lobby", "new:msg", %{body: "hi!"})
    refute_receive %Message{}
  end

  test "adapter handles refuses websocket events that haven't joined" do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:#{@port}/ws")

    WebsocketClient.send_event(sock, "rooms:lobby", "new:msg", %{body: "hi!"})
    refute_receive {:socket_reply, %Message{}}
  end

  ## Longpoller Transport

  @doc """
  Helper method to maintain token session state when making HTTP requests.

  Returns a response with body decoded into JSON map.
  """
  def poll(method, path, params, json \\ nil) do
    headers = %{"content-type" => "application/json"}
    body = Poison.encode!(json)
    url = "http://127.0.0.1:#{@port}#{path}?" <> URI.encode_query(params)

    {:ok, resp} = HTTPClient.request(method, url, headers, body)

    if resp.body != "" do
      put_in resp.body, Poison.decode!(resp.body)
    else
      resp
    end
  end

  test "adapter handles longpolling join, leave, and event messages" do
    # create session
    resp = poll :get, "/ws/poll", %{}, %{}
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.body["token"]
    assert resp.body["sig"]
    assert resp.status == 410

    # join
    resp = poll :post, "/ws/poll", session, %{
      "topic" => "rooms:lobby",
      "event" => "join",
      "payload" => %{}
    }
    assert resp.status == 200

    # poll with messsages sends buffer
    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 200
    [status_msg] = resp.body["messages"]
    assert status_msg["payload"] == %{"status" => "connected"}

    # poll without messages sends 204 no_content
    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 204

    # messages are buffered between polls
    Phoenix.Channel.broadcast! :int_pub, "rooms:lobby", "user:entered", %{name: "José"}
    Phoenix.Channel.broadcast! :int_pub, "rooms:lobby", "user:entered", %{name: "Sonny"}
    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 200
    assert Enum.count(resp.body["messages"]) == 2
    assert Enum.map(resp.body["messages"], &(&1["payload"]["name"])) == ["José", "Sonny"]

    # poll without messages sends 204 no_content
    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 204

    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 204

    # generic events
    Phoenix.PubSub.subscribe(:int_pub, self, "rooms:lobby")
    resp = poll :post, "/ws/poll", Map.take(resp.body, ["token", "sig"]), %{
      "topic" => "rooms:lobby",
      "event" => "new:msg",
      "payload" => %{"body" => "hi!"}
    }
    assert resp.status == 200
    assert_receive {:socket_broadcast, %Message{event: "new:msg", payload: %{"body" => "hi!"}}}
    resp = poll(:get, "/ws/poll", session)
    session = Map.take(resp.body, ["token", "sig"])
    assert resp.status == 200

    # unauthorized events
    capture_log fn ->
      Phoenix.PubSub.subscribe(:int_pub, self, "rooms:private-room")
      resp = poll :post, "/ws/poll", session, %{
        "topic" => "rooms:private-room",
        "event" => "new:msg",
        "payload" => %{"body" => "this method shouldn't send!'"}
      }
      assert resp.status == 401
      refute_receive {:socket_broadcast, %Message{event: "new:msg"}}


      ## multiplexed sockets

      # join
      resp = poll :post, "/ws/poll", session, %{
        "topic" => "rooms:room123",
        "event" => "join",
        "payload" => %{}
      }
      assert resp.status == 200
      Phoenix.Channel.broadcast! :int_pub, "rooms:lobby", "new:msg", %{body: "Hello lobby"}
      # poll
      resp = poll(:get, "/ws/poll", session)
      session = Map.take(resp.body, ["token", "sig"])
      assert resp.status == 200
      assert Enum.count(resp.body["messages"]) == 2
      assert Enum.at(resp.body["messages"], 0)["payload"]["status"] == "connected"
      assert Enum.at(resp.body["messages"], 1)["payload"]["body"] == "Hello lobby"


      ## Server termination handling

      # 410 from crashed/terminated longpoller server when polling
      :timer.sleep @ensure_window_timeout_ms
      resp = poll(:get, "/ws/poll", session)
      session = Map.take(resp.body, ["token", "sig"])
      assert resp.status == 410

      # join
      resp = poll :post, "/ws/poll", session, %{
        "topic" => "rooms:lobby",
        "event" => "join",
        "payload" => %{}
      }
      assert resp.status == 200
      Phoenix.PubSub.subscribe(:int_pub, self, "rooms:lobby")
      :timer.sleep @ensure_window_timeout_ms
      resp = poll :post, "/ws/poll", session, %{
        "topic" => "rooms:lobby",
        "event" => "new:msg",
        "payload" => %{"body" => "hi!"}
      }
      assert resp.status == 410
      refute_receive {:socket_reply, %Message{event: "new:msg", payload: %{"body" => "hi!"}}}

      # 410 from crashed/terminated longpoller server when publishing
      # create new session
      resp = poll :post, "/ws/poll", %{"token" => "foo", "sig" => "bar"}, %{}
      assert resp.status == 410
    end
  end
end
