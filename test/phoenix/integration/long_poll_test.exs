Code.require_file "../../support/http_client.exs", __DIR__

defmodule Phoenix.Integration.LongPollTest do
  # TODO: Make this test async
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Transports.{V2, LongPollSerializer}
  alias Phoenix.PubSub.Local
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5808
  @pool_size 1

  handler =
    case Application.spec(:cowboy, :vsn) do
      [?2 | _] -> Phoenix.Endpoint.Cowboy2Handler
      _ -> Phoenix.Endpoint.CowboyHandler
    end

  Application.put_env(:phoenix, Endpoint, [
    https: false,
    http: [port: @port],
    handler: handler,
    secret_key_base: String.duplicate("abcdefgh", 8),
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__, pool_size: @pool_size]
  ])

  defmodule RoomChannel do
    use Phoenix.Channel, log_join: :info, log_handle_in: :info

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
      {:noreply, socket}
    end

    def handle_in("boom", _message, _socket) do
      raise "boom"
    end

    def handle_out("new_msg", payload, socket) do
      push socket, "new_msg", Map.put(payload, "transport", inspect(socket.transport))
      {:noreply, socket}
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

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

    channel "room:*", RoomChannel

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

  setup config do
    supervisor = Module.concat(Endpoint, "LongPoll.Supervisor")
    for {_, pid, _, _} <- Supervisor.which_children(supervisor) do
      Supervisor.terminate_child(supervisor, pid)
    end
    {:ok, topic: "room:" <> to_string(config.test)}
  end

  def assert_down(topic) do
    ref = Process.monitor(Process.whereis(:"#{topic}"))
    assert_receive {:DOWN, ^ref, :process, _pid, _}
  end

  @doc """
  Helper method to maintain token session state when making HTTP requests.

  Returns a response with body decoded into JSON map.
  """
  def poll(method, path, vsn, params, json \\ nil, headers \\ %{}) do
    headers = Map.merge(%{"content-type" => "application/json"}, headers)
    body = encode(vsn, json)
    query_str = params |> Map.put("vsn", vsn) |> URI.encode_query()
    url = "http://127.0.0.1:#{@port}#{path}/longpoll?" <> query_str

    {:ok, resp} = HTTPClient.request(method, url, headers, body)

    decode_body(vsn, resp)
  end
  defp decode_body(_vsn, %{body: ""} = resp), do: resp
  defp decode_body("1." <> _, %{} = resp) do
    put_in(resp, [:body], Phoenix.json_library().decode!(resp.body))
  end
  defp decode_body("2." <> _, %{} = resp) do
    resp
    |> put_in([:body], Phoenix.json_library().decode!(resp.body))
    |> update_in([:body, "messages"], fn
      nil -> []
      messages ->
        for msg <- messages do
          msg
          |> V2.LongPollSerializer.decode!([])
          |> stringify()
        end
    end)
  end
  defp decode_body(_invalid, %{} = resp) do
    put_in(resp, [:body], Phoenix.json_library().decode!(resp.body))
  end
  def stringify(struct) do
    struct
    |> Map.from_struct()
    |> Phoenix.json_library().encode!()
    |> Phoenix.json_library().decode!()
  end

  defp encode(_vsn, nil), do: ""
  defp encode("1." <> _ = _vsn, map), do: Phoenix.json_library().encode!(map)
  defp encode("2." <> _ = _vsn, map) do
    Phoenix.json_library().encode!(
      [map["join_ref"], map["ref"], map["topic"], map["event"], map["payload"]])
  end
  defp encode(_, map), do: encode("1.0.0", map)

  @doc """
  Joins a long poll socket.

  Returns the long polling session token.

  If the mode is local, the session will point to a local
  process. If the mode is pubsub, the session will use the
  pubsub system.
  """
  def join(path, topic, vsn, mode \\ :local, payload \\ %{})

  def join(path, topic, vsn, :local, payload) do
    resp = poll :get, path, vsn, %{}, %{}
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200

    session = Map.take(resp.body, ["token"])

    resp = poll :post, path, vsn, session, %{
      "topic" => topic,
      "event" => "phx_join",
      "ref" => "123",
      "join_ref" => "123",
      "payload" => payload
    }
    assert resp.body["status"] == 200

    session
  end

  def join(path, topic, vsn, :pubsub, payload) do
    session = join(path, topic, vsn, :local, payload)
    {:ok, {:v1, _id, pid, topic}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__), session["token"])
    %{"token" =>
      Phoenix.Token.sign(Endpoint, Atom.to_string(__MODULE__), {:v1, "unknown", pid, topic})}
  end

  for mode <- [:local, :pubsub] do
    @mode mode
    @vsn "1.0.0"

    test "#{@mode}: joins and poll messages" do
      session = join("/ws", "room:lobby", @vsn, @mode)

      # pull messages
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 200

      [phx_reply, user_entered, status_msg] = resp.body["messages"]

      assert phx_reply ==
        %{"event" => "phx_reply",
          "payload" => %{"response" => %{}, "status" => "ok"},
          "ref" => "123", "topic" => "room:lobby", "join_ref" => "123"}
      assert status_msg ==
        %{"event" => "joined",
          "payload" => %{"status" => "connected", "user_id" => nil},
          "ref" => nil, "join_ref" => nil, "topic" => "room:lobby"}
      assert user_entered ==
        %{"event" => "user_entered",
          "payload" => %{"user" => nil},
          "ref" => nil, "join_ref" => nil, "topic" => "room:lobby"}

      # poll without messages sends 204 no_content
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 204
    end

    test "#{@mode}: publishing events" do
      Phoenix.PubSub.subscribe(__MODULE__, "room:lobby")
      session = join("/ws", "room:lobby", @vsn, @mode)

      # Publish successfully
      resp = poll :post, "/ws", @vsn, session, %{
        "topic" => "room:lobby",
        "event" => "new_msg",
        "ref" => "123",
        "payload" => %{"body" => "hi!"}
      }
      assert resp.body["status"] == 200
      assert_receive %Broadcast{event: "new_msg", payload: %{"body" => "hi!"}}

      # Get published message
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 200
      assert List.last(resp.body["messages"]) ==
        %{"event" => "new_msg",
          "payload" => %{"transport" => "Phoenix.Transports.LongPoll", "body" => "hi!"},
          "ref" => nil,
          "join_ref" => nil,
          "topic" => "room:lobby"}

      # Publish unauthorized event
      capture_log fn ->
        Phoenix.PubSub.subscribe(__MODULE__, "room:private-room")
        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:private-room",
          "event" => "new_msg",
          "ref" => "12300",
          "payload" => %{"body" => "this method shouldn't send!'"}
        }
        assert resp.body["status"] == 401
        refute_receive %Broadcast{event: "new_msg"}
      end
    end

    test "#{@mode}: shuts down after timeout" do
      session = join("/ws", "room:lobby", @vsn, @mode)

      channel = Process.whereis(:"room:lobby")
      assert channel
      Process.monitor(channel)

      assert_receive({:DOWN, _, :process, ^channel, {:shutdown, :inactive}}, 5000)
      resp = poll(:post, "/ws", @vsn, session)
      assert resp.body["status"] == 410
    end
  end

  for {serializer, vsn} <- [{LongPollSerializer, "1.0.0"},
                            {V2.LongPollSerializer, "2.0.0"}] do
    @vsn vsn
    @join_ref "123"

    describe "with #{vsn} serializer #{inspect serializer}" do
      test "refuses connects that error with 403 response" do
        resp = poll :get, "/ws", @vsn, %{"reject" => "true"}, %{}
        assert resp.body["status"] == 403
      end

      test "refuses unallowed origins" do
        capture_log fn ->
          resp = poll(:get, "/ws", @vsn, %{}, nil, %{"origin" => "https://example.com"})
          assert resp.body["status"] == 410

          resp = poll(:get, "/ws", @vsn, %{}, nil, %{"origin" => "http://notallowed.com"})
          assert resp.body["status"] == 403
        end
      end

      test "shuts down on pubsub crash" do
        session = join("/ws", "room:lobby", @vsn)

        channel = Process.whereis(:"room:lobby")
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

        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:lobby",
          "event" => "new_msg",
          "ref" => "123",
          "payload" => %{"body" => "hi!"}
        }
        assert resp.body["status"] == 410
        assert_receive {:DOWN, _, :process, ^channel, _}
      end

      test "filter params on join" do
        log = capture_log fn ->
          join("/ws/logging", "room:lobby", @vsn, :local, %{"foo" => "bar", "password" => "shouldnotshow"})
        end
        assert log =~ "Parameters: %{\"foo\" => \"bar\", \"password\" => \"[FILTERED]\"}"
      end

      test "sends phx_error if a channel server abnormally exits", %{topic: topic} do
        session = join("/ws", topic, @vsn)

        capture_log fn ->
          resp = poll :post, "/ws", @vsn, session, %{
            "topic" => topic,
            "event" => "boom",
            "ref" => @join_ref,
            "join_ref" => @join_ref,
            "payload" => %{}
          }
          assert resp.body["status"] == 200
          assert resp.status == 200
        end
        assert_down(topic)

        resp = poll(:get, "/ws", @vsn, session)
        [_phx_reply, _user_entered, _joined, chan_error] = resp.body["messages"]

        assert chan_error ==
          %{"event" => "phx_error", "payload" => %{}, "topic" => topic,
            "ref" => "123", "join_ref" => @join_ref}
      end

      test "sends phx_close if a channel server normally exits" do
        session = join("/ws", "room:lobby", @vsn)

        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:lobby",
          "event" => "phx_leave",
          "ref" => "2",
          "payload" => %{}
        }
        assert resp.body["status"] == 200
        assert resp.status == 200

        resp = poll(:get, "/ws", @vsn, session)

        [_phx_reply, _joined, _user_entered, _leave_reply, phx_close] = resp.body["messages"]

        assert phx_close ==
          %{"event" => "phx_close", "payload" => %{},
            "ref" => "123",
            "join_ref" => @join_ref,
            "topic" => "room:lobby"}
      end

      test "shuts down when receiving disconnect broadcasts on socket's id" do
        resp = poll :get, "/ws", @vsn, %{"user_id" => "456"}, %{}
        session = Map.take(resp.body, ["token"])

        for topic <- ["room:lpdisconnect1", "room:lpdisconnect2"] do
          poll :post, "/ws", @vsn, session, %{
            "topic" => topic,
            "event" => "phx_join",
            "ref" => "1",
            "payload" => %{}
          }
        end

        chan1 = Process.whereis(:"room:lpdisconnect1")
        assert chan1
        chan2 = Process.whereis(:"room:lpdisconnect2")
        assert chan2
        Process.monitor(chan1)
        Process.monitor(chan2)

        Endpoint.broadcast("user_sockets:456", "disconnect", %{})

        assert_receive {:DOWN, _, :process, ^chan1, {:shutdown, :disconnected}}
        assert_receive {:DOWN, _, :process, ^chan2, {:shutdown, :disconnected}}

        poll(:get, "/ws", @vsn, session)
        assert resp.body["status"] == 410
      end

      test "refuses non-matching versions" do
        log = capture_log fn ->
          resp = poll(:get, "/ws", "123.1.1", %{}, nil, %{"origin" => "https://example.com"})
          assert resp.body["status"] == 403
        end
        assert log =~ "The client's requested channel transport version \"123.1.1\" does not match server's version"
      end

      test "forces application/json content-type" do
        session = join("/ws", "room:lobby", @vsn)

        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:lobby",
          "event" => "phx_leave",
          "ref" => "2",
          "payload" => %{}
        }, %{"content-type" => ""}
        assert resp.body["status"] == 200
        assert resp.status == 200
      end
    end
  end
end
