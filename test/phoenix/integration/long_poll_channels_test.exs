Code.require_file "../../support/http_client.exs", __DIR__

defmodule Phoenix.Integration.LongPollChannelsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.HTTPClient
  alias Phoenix.Socket.{Broadcast, Message, V1, V2}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5808
  @pool_size 1

  Application.put_env(:phoenix, Endpoint, [
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    server: true,
    pubsub_server: __MODULE__
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

  defmodule UserSocketConnectInfo do
    use Phoenix.Socket

    channel "room:*", RoomChannel

    def connect(params, socket, connect_info) do
      unless params["logging"] == "enabled", do: Logger.disable(self())
      address = Tuple.to_list(connect_info.peer_data.address) |> Enum.join(".")
      trace_context_headers = Enum.into(connect_info.trace_context_headers, %{})
      uri = Map.from_struct(connect_info.uri)
      x_headers = Enum.into(connect_info.x_headers, %{})

      connect_info =
        connect_info
        |> update_in([:peer_data], &Map.put(&1, :address, address))
        |> Map.put(:trace_context_headers, trace_context_headers)
        |> Map.put(:uri, uri)
        |> Map.put(:x_headers, x_headers)

      socket =
        socket
        |> assign(:user_id, params["user_id"])
        |> assign(:connect_info, connect_info)

      {:ok, socket}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

    def connect(%{"reject" => "true"}, _socket) do
      :error
    end

    def connect(%{"custom_error" => "true"}, _socket) do
      {:error, :custom}
    end

    def connect(params, socket) do
      unless params["logging"] == "enabled", do: Logger.disable(self())
      {:ok, assign(socket, :user_id, params["user_id"])}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket,
      longpoll: [
        window_ms: 200,
        pubsub_timeout_ms: 200,
        check_origin: ["//example.com"]
      ]

    socket "/ws/admin", UserSocket,
      longpoll: [
        window_ms: 200,
        pubsub_timeout_ms: 200,
        check_origin: ["//example.com"]
      ]

    socket "/ws/connect_info", UserSocketConnectInfo,
      longpoll: [
        window_ms: 200,
        pubsub_timeout_ms: 200,
        check_origin: ["//example.com"],
        connect_info: [:trace_context_headers, :x_headers, :peer_data, :uri]
      ]
  end

  setup_all do
    capture_log(fn -> start_supervised! Endpoint end)
    start_supervised! {Phoenix.PubSub, name: __MODULE__, pool_size: @pool_size}
    :ok
  end

  setup config do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Phoenix.Transports.LongPoll.Supervisor) do
      DynamicSupervisor.terminate_child(Phoenix.Transports.LongPoll.Supervisor, pid)
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
    {serializer, json} = serializer(vsn, json)
    headers =
      if is_list(json) do
        Map.merge(%{"content-type" => "application/x-ndjson"}, headers)
      else
        Map.merge(%{"content-type" => "application/json"}, headers)
      end

    body = encode(serializer, json)
    query_string = params |> Map.put("vsn", vsn) |> URI.encode_query()
    url = "http://127.0.0.1:#{@port}#{path}/longpoll?" <> query_string
    {:ok, resp} = HTTPClient.request(method, url, headers, body)
    decode_body(serializer, resp)
  end

  defp serializer("2." <> _, json), do: {V2.JSONSerializer, json}
  defp serializer(_, nil), do: {V1.JSONSerializer, nil}
  defp serializer(_, batch) when is_list(batch) do
    {V1.JSONSerializer, for(msg <- batch, do: Map.delete(msg, "join_ref"))}
  end
  defp serializer(_, %{} = json) do
    {V1.JSONSerializer, json}
  end

  defp decode_body(serializer, %{} = resp) do
    resp
    |> update_in([:body], &Phoenix.json_library().decode!(&1))
    |> update_in([:body, "messages"], fn messages ->
      for msg <- messages || [] do
        serializer.decode!(msg, opcode: :text)
      end
    end)
  end

  defp encode(_vsn, nil), do: ""

  defp encode(V2.JSONSerializer = serializer, batch) when is_list(batch) do
    batch
    |> Enum.map(&encode(serializer, &1))
    |> Enum.join("\n")
  end

  defp encode(V2.JSONSerializer, %{} = map) do
    Phoenix.json_library().encode!(
      [map["join_ref"], map["ref"], map["topic"], map["event"], map["payload"]]
    )
  end

  defp encode(V1.JSONSerializer, %{} = map), do: Phoenix.json_library().encode!(map)

  @doc """
  Joins a long poll socket.

  Returns the long polling session token.

  If the mode is local, the session will point to a local
  process. If the mode is pubsub, the session will use the
  pubsub system.
  """
  def join(path, topic, vsn, join_ref, mode \\ :local, payload \\ %{}, params \\ %{}, headers \\ %{})

  def join(path, topic, vsn, join_ref, :local, payload, params, headers) do
    resp = poll :get, path, vsn, params, %{}, headers
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200

    session = resp.body |> Map.take(["token"]) |> Map.merge(params)
    resp = poll :post, path, vsn, session, %{
      "topic" => topic,
      "event" => "phx_join",
      "ref" => "1",
      "join_ref" => join_ref,
      "payload" => payload
    }, headers

    assert resp.body["status"] == 200
    session
  end

  def join(path, topic, vsn, join_ref, :pubsub, payload, params, headers) do
    session = join(path, topic, vsn, join_ref, :local, payload, params, headers)

    {:ok, {:v1, _id, pid, topic}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__), session["token"])

    %{"token" =>
      Phoenix.Token.sign(Endpoint, Atom.to_string(__MODULE__), {:v1, "unknown", pid, topic})}
  end

  for mode <- [:local, :pubsub] do
    @mode mode
    @vsn "1.0.0"

    test "#{@mode}: joins and poll messages" do
      session = join("/ws", "room:lobby", @vsn, "1", @mode)

      # pull messages
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 200

      [phx_reply, user_entered, status_msg] = resp.body["messages"]

      assert phx_reply == %Message{
        event: "phx_reply",
        payload: %{"response" => %{}, "status" => "ok"},
        ref: "1",
        topic: "room:lobby"
      }

      assert %Message{
        event: "joined",
        payload: %{"status" => "connected", "user_id" => nil},
        ref: nil,
        join_ref: nil,
        topic: "room:lobby"
      } = status_msg

      assert user_entered == %Message{
        event: "user_entered",
        payload: %{"user" => nil},
        ref: nil,
        join_ref: nil,
        topic: "room:lobby"
      }

      # poll without messages sends 204 no_content
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 204
    end

    test "#{@mode}: transport x_headers are extracted to the socket connect_info" do
      session = join("/ws/connect_info", "room:lobby", @vsn, "1", @mode, %{}, %{}, %{"x-application" => "Phoenix"})

      # pull messages
      resp = poll(:get, "/ws/connect_info", @vsn, session)
      assert resp.body["status"] == 200

      [_phx_reply, _user_entered, status_msg] = resp.body["messages"]

      assert %{"connect_info" =>
               %{"x_headers" =>
                 %{"x-application" => "Phoenix"}}} = status_msg.payload
    end

    test "#{@mode}: transport trace_context_headers are extracted to the socket connect_info" do
      ctx_headers =
        %{"traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
        "tracestate" => "congo=t61rcWkgMz"}
      session = join("/ws/connect_info", "room:lobby", @vsn, "1", @mode, %{}, %{}, ctx_headers)

      # pull messages
      resp = poll(:get, "/ws/connect_info", @vsn, session)
      assert resp.body["status"] == 200

      [_phx_reply, _user_entered, status_msg] = resp.body["messages"]

      assert %{"connect_info" =>
        %{"trace_context_headers" =>
           ^ctx_headers}} = status_msg.payload
    end

    test "#{@mode}: transport peer_data is extracted to the socket connect_info" do
      session = join("/ws/connect_info", "room:lobby", @vsn, "1", @mode, %{}, %{}, %{"x-application" => "Phoenix"})

      # pull messages
      resp = poll(:get, "/ws/connect_info", @vsn, session)
      assert resp.body["status"] == 200

      [_phx_reply, _user_entered, status_msg] = resp.body["messages"]

      assert %{"connect_info" =>
               %{"peer_data" =>
                 %{"address" => "127.0.0.1"}}} = status_msg.payload
    end

    test "#{@mode}: transport uri is extracted to the socket connect_info" do
      session = join("/ws/connect_info", "room:lobby", @vsn, "1", @mode, %{}, %{}, %{"x-application" => "Phoenix"})

      # pull messages
      resp = poll(:get, "/ws/connect_info", @vsn, session)
      assert resp.body["status"] == 200

      [_phx_reply, _user_entered, status_msg] = resp.body["messages"]
      query = "vsn=#{@vsn}"
      assert %{"connect_info" =>
                %{"uri" =>
                  %{"host" => "127.0.0.1",
                    "path" => "/ws/connect_info/longpoll",
                    "query" => ^query,
                    "scheme" => "http"}}} = status_msg.payload
    end

    test "#{@mode}: publishing events" do
      Phoenix.PubSub.subscribe(__MODULE__, "room:lobby")
      session = join("/ws", "room:lobby", @vsn, "1", @mode)

      # Publish successfully
      resp = poll :post, "/ws", @vsn, session, %{
        "topic" => "room:lobby",
        "event" => "new_msg",
        "ref" => "1",
        "payload" => %{"body" => "hi!"}
      }
      assert resp.body["status"] == 200
      assert_receive %Broadcast{event: "new_msg", payload: %{"body" => "hi!"}}

      # Get published message
      resp = poll(:get, "/ws", @vsn, session)
      assert resp.body["status"] == 200
      assert List.last(resp.body["messages"]) == %Message{
        event: "new_msg",
        payload: %{"transport" => ":longpoll", "body" => "hi!"},
        ref: nil,
        join_ref: nil,
        topic: "room:lobby"
      }

      # Publish event to an unjoined room
      capture_log fn ->
        Phoenix.PubSub.subscribe(__MODULE__, "room:private-room")
        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:private-room",
          "event" => "new_msg",
          "ref" => "12300",
          "payload" => %{"body" => "this method shouldn't send!'"}
        }
        assert resp.body["status"] == 200
        refute_receive %Broadcast{event: "new_msg"}

        # Get join error
        resp = poll(:get, "/ws", @vsn, session)
        assert resp.body["status"] == 200
        assert List.last(resp.body["messages"]) == %Message{
          join_ref: nil,
          event: "phx_reply",
          payload: %{"response" => %{"reason" => "unmatched topic"}, "status" => "error"},
          ref: "12300",
          topic: "room:private-room"
        }
      end
    end

    test "#{@mode}: lonpoll publishing batch events on v2 protocol" do
      vsn = "2.0.0"
      Phoenix.PubSub.subscribe(__MODULE__, "room:lobby")
      session = join("/ws", "room:lobby", vsn, "1", @mode)
      # Publish successfully
      resp =
        poll(:post, "/ws", vsn, session, [
          %{
            "topic" => "room:lobby",
            "event" => "new_msg",
            "ref" => "2",
            "join_ref" => "1",
            "payload" => %{"body" => "hi1"}
          },
          %{
            "topic" => "room:lobby",
            "event" => "new_msg",
            "ref" => "3",
            "join_ref" => "1",
            "payload" => %{"body" => "hi2"}
          }
        ])


      assert resp.body["status"] == 200
      assert_receive %Broadcast{event: "new_msg", payload: %{"body" => "hi1"}}
      assert_receive %Broadcast{event: "new_msg", payload: %{"body" => "hi2"}}

      # Get published message
      resp = poll(:get, "/ws", vsn, session)
      assert resp.body["status"] == 200

      assert [
               _phx_reply,
               _user_entered,
               _joined,
               %Message{
                 topic: "room:lobby",
                 event: "new_msg",
                 payload: %{"body" => "hi1", "transport" => ":longpoll"},
                 ref: nil,
                 join_ref: "1"
               },
               %Message{
                 topic: "room:lobby",
                 event: "new_msg",
                 payload: %{"body" => "hi2", "transport" => ":longpoll"},
                 ref: nil,
                 join_ref: "1"
               }
             ] = resp.body["messages"]
    end

    test "#{@mode}: shuts down after timeout" do
      session = join("/ws", "room:lobby", @vsn, "1", @mode)

      channel = Process.whereis(:"room:lobby")
      assert channel
      Process.monitor(channel)

      assert_receive({:DOWN, _, :process, ^channel, {:shutdown, :inactive}}, 5000)
      resp = poll(:post, "/ws", @vsn, session)
      assert resp.body["status"] == 410
    end
  end

  for {serializer, vsn, join_ref} <- [{V1.JSONSerializer, "1.0.0", nil}, {V2.JSONSerializer, "2.0.0", "1"}] do
    @vsn vsn
    @join_ref join_ref

    describe "with #{vsn} serializer #{inspect serializer}" do
      test "refuses connects that error with 403 response" do
        resp = poll :get, "/ws", @vsn, %{"reject" => "true"}, %{}
        assert resp.body["status"] == 403

        resp = poll :get, "/ws", @vsn, %{"custom_error" => "true"}, %{}
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

      test "filter params on join" do
        log = capture_log fn ->
          join("/ws", "room:lobby", @vsn, @join_ref, :local, %{"foo" => "bar", "password" => "shouldnotshow"}, %{"logging" => "enabled"})
        end
        assert log =~ "Parameters: %{\"foo\" => \"bar\", \"password\" => \"[FILTERED]\"}"
      end

      test "sends phx_error if a channel server abnormally exits", %{topic: topic} do
        session = join("/ws", topic, @vsn, @join_ref)

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

        assert chan_error == %Message{
          event: "phx_error",
          payload: %{},
          topic: topic,
          ref: @join_ref,
          join_ref: @join_ref
        }
      end

      test "sends phx_close if a channel server normally exits" do
        session = join("/ws", "room:lobby", @vsn, @join_ref)

        resp =
          poll :post, "/ws", @vsn, session, %{
            "topic" => "room:lobby",
            "event" => "phx_leave",
            "join_ref" => @join_ref,
            "ref" => "2",
            "payload" => %{}
          }

        assert resp.body["status"] == 200
        assert resp.status == 200

        resp = poll(:get, "/ws", @vsn, session)
        [_phx_reply, _joined, _user_entered, _leave_reply, phx_close] = resp.body["messages"]

        assert phx_close == %Message{
          event: "phx_close",
          payload: %{},
          ref: @join_ref,
          join_ref: @join_ref,
          topic: "room:lobby"
        }
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
        assert log =~ "The client's requested transport version \"123.1.1\" does not match server's version"
      end

      test "forces application/json content-type" do
        session = join("/ws", "room:lobby", @vsn, @join_ref)

        resp = poll :post, "/ws", @vsn, session, %{
          "topic" => "room:lobby",
          "event" => "phx_leave",
          "ref" => "2",
          "join_ref" => @join_ref,
          "payload" => %{}
        }, %{"content-type" => ""}
        assert resp.body["status"] == 200
        assert resp.status == 200
      end
    end
  end
end
