Code.require_file "websocket_client.exs", __DIR__
Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.ChannelTest do
  use ExUnit.Case, async: true
  import RouterHelper, only: [capture_log: 1]

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Socket.Message

  @port 5807
  @window_ms 100
  @ensure_window_timeout_ms @window_ms * 3

  Application.put_env(:channel_app, __MODULE__.Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    debug_errors: false,
    transports: [longpoller_window_ms: @window_ms],
    server: true
  ])

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(socket, _topic, message) do
      reply socket, "join", %{status: "connected"}
      broadcast socket, "user:entered", %{user: message["user"]}
      {:ok, socket}
    end

    def leave(socket, _message) do
      reply socket, "you:left", %{message: "bye!"}
      socket
    end

    def incoming(socket, "new:msg", message) do
      broadcast socket, "new:msg", message
      socket
    end
  end

  defmodule Router do
    use Phoenix.Router, socket_mount: "/ws"

    def call(conn, opts) do
      Logger.disable(self)
      super(conn, opts)
    end

    channel "rooms:*", RoomChannel
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
  Helper method to maintain cookie session state when making HTTP requests.

  Returns a response with body decoded into JSON map.
  """
  def poll(method, cookie, json \\ nil) do
    headers = if cookie, do: %{"Cookie" => cookie}, else: %{}

    if json do
      headers = Dict.merge(headers, %{"content-type" => "application/json"})
      body    = Poison.encode!(json)
    end

    {:ok, resp} = HTTPClient.request(method, "http://127.0.0.1:#{@port}/ws/poll", headers, body)

    if resp.body != "" do
      resp = put_in resp.body, Poison.decode!(resp.body)
    end

    case resp.headers |> Enum.into(%{}) |> Map.get('set-cookie') |> to_string do
      ""         -> {resp, cookie}
      new_cookie -> {resp, new_cookie}
    end
  end

  test "adapter handles longpolling join, leave, and event messages" do
    # create session
    {resp, cookie} = poll :post, nil, %{}
    assert resp.status == 200

    # join
    {resp, cookie} = poll :put, cookie, %{"topic" => "rooms:lobby",
                                          "event" => "join",
                                          "payload" => %{}}
    assert resp.status == 200

    # poll with messsages sends buffer
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 200
    [status_msg] = resp.body
    assert status_msg["payload"] == %{"status" => "connected"}

    # poll without messages sends 204 no_content
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 204

    # messages are buffered between polls
    Phoenix.Channel.broadcast "rooms:lobby", "user:entered", %{name: "José"}
    Phoenix.Channel.broadcast "rooms:lobby", "user:entered", %{name: "Sonny"}
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 200
    assert Enum.count(resp.body) == 2
    assert Enum.map(resp.body, &(&1["payload"]["name"])) == ["José", "Sonny"]

    # poll without messages sends 204 no_content
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 204

    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 204

    # generic events
    Phoenix.Channel.subscribe(self, "rooms:lobby")
    {resp, cookie} = poll :put, cookie, %{"topic" => "rooms:lobby",
                                          "event" => "new:msg",
                                          "payload" => %{"body" => "hi!"}}
    assert resp.status == 200
    assert_receive {:socket_broadcast, %Message{event: "new:msg", payload: %{"body" => "hi!"}}}
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 200

    # unauthorized events
    Phoenix.Channel.subscribe(self, "rooms:private-room")
    {resp, cookie} = poll :put, cookie, %{"topic" => "rooms:private-room",
                                          "event" => "new:msg",
                                          "payload" => %{"body" => "this method shouldn't send!'"}}
    assert resp.status == 401
    refute_receive {:socket_broadcast, %Message{event: "new:msg"}}


    ## multiplexed sockets

    # join
    {resp, cookie} = poll :put, cookie, %{"topic" => "rooms:room123",
                                          "event" => "join",
                                          "payload" => %{}}
    assert resp.status == 200
    Phoenix.Channel.broadcast "rooms:lobby", "new:msg", %{body: "Hello lobby"}
    # poll
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 200
    assert Enum.count(resp.body) == 2
    assert Enum.at(resp.body, 0)["payload"]["status"] == "connected"
    assert Enum.at(resp.body, 1)["payload"]["body"] == "Hello lobby"


    ## Server termination handling

    # 410 from crashed/terminated longpoller server when polling
    :timer.sleep @ensure_window_timeout_ms
    {resp, cookie} = poll(:get, cookie)
    assert resp.status == 410


    # 410 from crashed/terminated longpoller server when publishing
    # create new session
    {resp, cookie} = poll :post, cookie, %{}
    assert resp.status == 200

    # join
    {resp, cookie} = poll :put, cookie, %{"topic" => "rooms:lobby",
                                          "event" => "join",
                                          "payload" => %{}}
    assert resp.status == 200
    Phoenix.Channel.subscribe(self, "rooms:lobby")
    :timer.sleep @ensure_window_timeout_ms
    {resp, _cookie} = poll :put, cookie, %{"topic" => "rooms:lobby",
                                          "event" => "new:msg",
                                          "payload" => %{"body" => "hi!"}}
    assert resp.status == 410
    refute_receive {:socket_reply, %Message{event: "new:msg", payload: %{"body" => "hi!"}}}
  end
end
