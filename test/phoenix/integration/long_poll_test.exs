Code.require_file "../../support/http_client.exs", __DIR__

defmodule Phoenix.Integration.LongPollTest do
  # TODO: Make this test async
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Transports.LongPoll
  alias Phoenix.Socket.Broadcast
  alias Phoenix.PubSub.Local
  alias __MODULE__.Endpoint

  @port 5808
  @pool_size 1

  Application.put_env(:phoenix, Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__, pool_size: @pool_size]
  ])

  defmodule RoomChannel do
    use Phoenix.Channel

    intercept ["new_msg"]

    def join(topic, message, socket) do
      Process.register(self, String.to_atom(topic))
      send(self, {:after_join, message})
      {:ok, socket}
    end

    def handle_info({:after_join, message}, socket) do
      broadcast socket, "user_entered", %{user: message["user"]}
      push socket, "joined", Map.merge(%{status: "connected"}, socket.assigns)
      {:noreply, socket}
    end

    def handle_in("new_msg", message, socket) do
      broadcast! socket, "new_msg", message
      {:noreply, socket}
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

    channel "rooms:*", RoomChannel

    transport :longpoll, Phoenix.Transports.LongPoll,
      window_ms: 200,
      pubsub_timeout_ms: 200,
      check_origin: ["//example.com"]

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

    channel "rooms:*", RoomChannel

    transport :longpoll, Phoenix.Transports.LongPoll,
      window_ms: 200,
      pubsub_timeout_ms: 200,
      check_origin: ["//example.com"]

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

  setup do
    for {_, pid, _, _} <- Supervisor.which_children(LongPoll.Supervisor) do
      Supervisor.terminate_child(LongPoll.Supervisor, pid)
    end
    :ok
  end

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

  @doc """
  Joins a long poll socket.

  Returns the long polling session token.

  If the mode is local, the session will point to a local
  process. If the mode is pubsub, the session will use the
  pubsub system.
  """
  def join(path, topic, mode \\ :local, payload \\ %{})

  def join(path, topic, :local, payload) do
    resp = poll :get, path, %{}, %{}
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200

    session = Map.take(resp.body, ["token"])

    resp = poll :post, path, session, %{
      "topic" => topic,
      "event" => "phx_join",
      "ref" => "123",
      "payload" => payload
    }
    assert resp.body["status"] == 200

    session
  end

  def join(path, topic, :pubsub, payload) do
    session = join(path, topic, :local, payload)
    {:ok, {:v1, _id, pid, topic}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__), session["token"])
    %{"token" =>
      Phoenix.Token.sign(Endpoint, Atom.to_string(__MODULE__), {:v1, "unknown", pid, topic})}
  end

  for mode <- [:local, :pubsub] do
    @mode mode

    test "#{@mode}: joins and poll messages" do
      session = join("/ws", "rooms:lobby", @mode)

      # pull messages
      resp = poll(:get, "/ws", session)
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
        %{"event" => "user_entered",
          "payload" => %{"user" => nil},
          "ref" => nil, "topic" => "rooms:lobby"}

      # poll without messages sends 204 no_content
      resp = poll(:get, "/ws", session)
      assert resp.body["status"] == 204
    end

    test "#{@mode}: publishing events" do
      Phoenix.PubSub.subscribe(__MODULE__, self, "rooms:lobby")
      session = join("/ws", "rooms:lobby", @mode)

      # Publish successfuly
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:lobby",
        "event" => "new_msg",
        "ref" => "123",
        "payload" => %{"body" => "hi!"}
      }
      assert resp.body["status"] == 200
      assert_receive %Broadcast{event: "new_msg", payload: %{"body" => "hi!"}}

      # Get published message
      resp = poll(:get, "/ws", session)
      assert resp.body["status"] == 200
      assert List.last(resp.body["messages"]) ==
        %{"event" => "new_msg",
          "payload" => %{"transport" => "Phoenix.Transports.LongPoll", "body" => "hi!"},
          "ref" => nil,
          "topic" => "rooms:lobby"}

      # Publish unauthorized event
      capture_log fn ->
        Phoenix.PubSub.subscribe(__MODULE__, self, "rooms:private-room")
        resp = poll :post, "/ws", session, %{
          "topic" => "rooms:private-room",
          "event" => "new_msg",
          "ref" => "12300",
          "payload" => %{"body" => "this method shouldn't send!'"}
        }
        assert resp.body["status"] == 401
        refute_receive %Broadcast{event: "new_msg"}
      end
    end

    test "#{@mode}: shuts down after timeout" do
      session = join("/ws", "rooms:lobby", @mode)

      channel = Process.whereis(:"rooms:lobby")
      assert channel
      Process.monitor(channel)

      assert_receive({:DOWN, _, :process, ^channel, {:shutdown, :inactive}}, 5000)
      resp = poll(:post, "/ws", session)
      assert resp.body["status"] == 410
    end
  end

  test "refuses connects that error with 403 response" do
    resp = poll :get, "/ws", %{"reject" => "true"}, %{}
    assert resp.body["status"] == 403
  end

  test "refuses unallowed origins" do
    capture_log fn ->
      resp = poll(:get, "/ws", %{}, nil, %{"origin" => "https://example.com"})
      assert resp.body["status"] == 410

      resp = poll(:get, "/ws", %{}, nil, %{"origin" => "http://notallowed.com"})
      assert resp.body["status"] == 403
    end
  end

  test "shuts down on pubsub crash" do
    session = join("/ws", "rooms:lobby")

    channel = Process.whereis(:"rooms:lobby")
    assert channel
    Process.monitor(channel)

    capture_log fn ->
      for shard <- 0..(@pool_size - 1) do
        local_pubsub_server = Process.whereis(Local.local_name(__MODULE__, shard))
        Process.monitor(local_pubsub_server)
        Process.exit(local_pubsub_server, :kill)
        assert_receive {:DOWN, _, :process, ^local_pubsub_server, :killed}
      end
    end

    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "new_msg",
      "ref" => "123",
      "payload" => %{"body" => "hi!"}
    }
    assert resp.body["status"] == 410
    assert_receive {:DOWN, _, :process, ^channel, _}
  end

  test "filter params on join" do
    log = capture_log fn ->
      join("/ws/logging", "rooms:lobby", :local, %{"foo" => "bar", "password" => "shouldnotshow"})
    end
    assert log =~ "Parameters: %{\"foo\" => \"bar\", \"password\" => \"[FILTERED]\"}"
  end

  test "sends phx_error if a channel server abnormally exits" do
    session = join("/ws", "rooms:lobby")

    capture_log fn ->
      resp = poll :post, "/ws", session, %{
        "topic" => "rooms:lobby",
        "event" => "boom",
        "ref" => "123",
        "payload" => %{}
      }
      assert resp.body["status"] == 200
      assert resp.status == 200
    end

    resp = poll(:get, "/ws", session)
    [_phx_reply, _joined, _user_entered, _you_left_msg, chan_error] = resp.body["messages"]

    assert chan_error ==
      %{"event" => "phx_error", "payload" => %{}, "topic" => "rooms:lobby", "ref" => nil}
  end

  test "sends phx_close if a channel server normally exits" do
    session = join("/ws", "rooms:lobby")

    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_leave",
      "ref" => "2",
      "payload" => %{}
    }
    assert resp.body["status"] == 200
    assert resp.status == 200

    resp = poll(:get, "/ws", session)

    [_phx_reply, _joined, _user_entered, _leave_reply, _you_left_msg, phx_close] = resp.body["messages"]

    assert phx_close ==
      %{"event" => "phx_close", "payload" => %{}, "ref" => nil, "topic" => "rooms:lobby"}
  end

  test "shuts down when receiving disconnect broadcasts on socket's id" do
    resp = poll :get, "/ws", %{"user_id" => "456"}, %{}
    session = Map.take(resp.body, ["token"])

    for topic <- ["rooms:lpdisconnect1", "rooms:lpdisconnect2"] do
      poll :post, "/ws", session, %{
        "topic" => topic,
        "event" => "phx_join",
        "ref" => "1",
        "payload" => %{}
      }
    end

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

  test "refuses non-matching versions" do
    log = capture_log fn ->
      resp = poll(:get, "/ws", %{vsn: "123.1.1"}, nil, %{"origin" => "https://example.com"})
      assert resp.body["status"] == 403
    end
    assert log =~ "The client's requested channel transport version \"123.1.1\" does not match server's version"
  end

  test "forces application/json content-type" do
    session = join("/ws", "rooms:lobby")

    resp = poll :post, "/ws", session, %{
      "topic" => "rooms:lobby",
      "event" => "phx_leave",
      "ref" => "2",
      "payload" => %{}
    }, %{"content-type" => ""}
    assert resp.body["status"] == 200
    assert resp.status == 200
  end
end
