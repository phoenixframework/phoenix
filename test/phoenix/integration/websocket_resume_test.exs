Code.require_file("../../support/websocket_client.exs", __DIR__)
Code.require_file("../../support/http_client.exs", __DIR__)

defmodule Phoenix.Integration.WebSocketResumeTest do
  # TODO: use parameterized tests once we require Elixir 1.18
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Phoenix.Integration.{HTTPClient, WebsocketClient}
  alias Phoenix.Socket.{Message, V2}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5909

  Application.put_env(:phoenix, Endpoint,
    https: false,
    http: [port: @port],
    secret_key_base: String.duplicate("abcdefgh", 8),
    server: true,
    drainer: false,
    pubsub_server: __MODULE__
  )

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(topic, _message, socket) do
      Process.register(self(), String.to_atom(topic))
      send(self(), :after_join)
      {:ok, socket}
    end

    def handle_info(:after_join, socket) do
      push(socket, "joined", %{transport: inspect(socket.transport)})
      {:noreply, socket}
    end

    def handle_info({:push, event, payload}, socket) do
      push(socket, event, payload)
      {:noreply, socket}
    end

    def handle_in("echo", payload, socket) do
      push(socket, "echo", payload)
      {:noreply, socket}
    end

    def handle_in("binary", _payload, socket) do
      push(socket, "binary", {:binary, <<1, 2, 3>>})
      {:noreply, socket}
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

    def connect(%{"reject_connect" => "true"}, _socket, _connect_info), do: :error

    def connect(params, socket, _connect_info) do
      send(Process.whereis(:resume_test), {:connect, params})
      {:ok, assign(socket, :user_id, params["user_id"])}
    end

    def resume(%{"reject_resume" => "true"}, _socket, _connect_info), do: :error

    def resume(params, socket, _connect_info) do
      send(Process.whereis(:resume_test), {:resume, params})
      {:ok, socket}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end

    # the :resumable function of "/ws/users", which only lets users resume
    def resumable?(%{params: params} = transport_info, arg) do
      send(Process.whereis(:resume_test), {:resumable?, transport_info, arg})

      case params["user_id"] do
        "invalid" -> :invalid
        user_id -> is_binary(user_id)
      end
    end
  end

  defmodule PingSocket do
    @behaviour Phoenix.Socket.Transport

    def child_spec(_opts), do: :ignore
    def connect(_), do: {:ok, %{}}
    def init(state), do: {:ok, state}
    def handle_in({"ping:" <> payload, _}, state), do: {:reply, :ok, {:ping, payload}, state}
    def handle_info(_, state), do: {:ok, state}

    def handle_control({payload, opts}, state) do
      {:push, {:text, "#{opts[:opcode]}:#{payload}"}, state}
    end

    def terminate(_reason, _state), do: :ok
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket,
      websocket: [resumable: true, window_ms: 200],
      longpoll: [window_ms: 200, pubsub_timeout_ms: 200]

    socket "/ws/ping", PingSocket, websocket: [resumable: true, window_ms: 200]

    socket "/ws/plain", UserSocket, websocket: true

    socket "/ws/users", UserSocket,
      websocket: [resumable: {UserSocket, :resumable?, [:arg]}, window_ms: 200]

    # long polling waits longer for messages than a WebSocket session for its client
    socket "/ws/windows", UserSocket,
      websocket: [resumable: true, window_ms: 200],
      longpoll: [window_ms: 1000, pubsub_timeout_ms: 200]
  end

  setup %{adapter: adapter} do
    Process.register(self(), :resume_test)
    config = Application.get_env(:phoenix, Endpoint)
    Application.put_env(:phoenix, Endpoint, Keyword.merge(config, adapter: adapter))
    capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: __MODULE__})
    :ok
  end

  defp connect(params, path \\ "/ws") do
    query = URI.encode_query(Map.merge(%{"vsn" => "2.0.0"}, params))
    url = "ws://127.0.0.1:#{@port}#{path}/websocket?" <> query
    {:ok, client} = WebsocketClient.connect(self(), url, V2.JSONSerializer)
    client
  end

  defp control(client, event, payload) do
    json = Phoenix.json_library().encode!([nil, nil, "phoenix", event, payload])
    :ok = WebsocketClient.send(client, {:text, json})
  end

  # connects with a new session and returns its token
  defp new_session(params \\ %{}) do
    client = connect(Map.put(params, "phx:resumable", "1"))
    assert_receive %Message{topic: "phoenix", event: "phx_session", payload: %{"token" => token}}
    {client, token}
  end

  # connects to a socket that uses control frames and plain text messages
  defp new_ping_session do
    query = URI.encode_query(%{"vsn" => "2.0.0", "phx:resumable" => "1"})
    url = "ws://127.0.0.1:#{@port}/ws/ping/websocket?" <> query
    {:ok, client} = WebsocketClient.connect(self(), url, :noop)
    assert_receive {:text, "[null,null,\"phoenix\",\"phx_session\"," <> _ = session}

    [nil, nil, "phoenix", "phx_session", %{"token" => token}] =
      Phoenix.json_library().decode!(session)

    {client, token}
  end

  defp join(client, topic) do
    WebsocketClient.join(client, topic, %{})
    assert_receive %Message{event: "phx_reply", topic: ^topic, payload: %{"status" => "ok"}}
    assert_receive %Message{event: "joined", topic: ^topic}
    Process.whereis(String.to_atom(topic))
  end

  # the client resumes over a new connection with the join ref of the first one
  defp echo(client, payload) do
    json = Phoenix.json_library().encode!(["11", "99", "room:a", "echo", payload])
    :ok = WebsocketClient.send(client, {:text, json})
  end

  # drops the connection without closing it, like a network failure
  defp drop(client) do
    ref = Process.monitor(client)
    Process.unlink(client)
    Process.exit(client, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  defp resume(token, ack, params \\ %{}, path \\ "/ws") do
    client = connect(Map.merge(params, %{"phx:resumable" => "1", "phx:resume" => "1"}), path)
    control(client, "phx_resume", %{token: token, ack: ack})
    client
  end

  defp poll(method, token, params, body \\ nil, path \\ "/ws") do
    query = URI.encode_query(Map.merge(%{"vsn" => "2.0.0"}, params))
    url = "http://127.0.0.1:#{@port}#{path}/longpoll?" <> query

    headers =
      if token,
        do: %{"x-phoenix-longpoll-token" => token, "content-type" => "application/x-ndjson"},
        else: %{}

    {:ok, resp} = HTTPClient.request(method, url, headers, body || "")
    Phoenix.json_library().decode!(resp.body)
  end

  defp decode(messages) do
    for message <- messages, do: V2.JSONSerializer.decode!(message, opcode: :text)
  end

  # a token with the pid of the session, as when another session gets the pid
  # of a session that stopped
  defp forge_token(token, fun) do
    {:ok, {:v1, endpoint_id, session, priv_topic}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__), token)

    data = fun.({:v1, endpoint_id, session, priv_topic})
    Phoenix.Transports.Session.sign_token(Endpoint, data, crypto: [max_age: 1_209_600])
  end

  defp session(token) do
    {:ok, {:v1, _id, session, _topic}} =
      Phoenix.Token.verify(Endpoint, Atom.to_string(__MODULE__), token)

    session
  end

  for adapter <- [Bandit.PhoenixAdapter, Phoenix.Endpoint.Cowboy2Adapter] do
    describe "adapter: #{inspect(adapter)}" do
      @describetag adapter: adapter

      test "starts a session that the client resumes after losing its connection" do
        {client, token} = new_session()
        assert_received {:connect, _}
        channel = join(client, "room:a")
        # the client received the join reply and the joined push
        drop(client)

        # the channel keeps running and its messages are kept for the client
        send(channel, {:push, "missed", %{n: 1}})
        send(channel, {:push, "missed", %{n: 2}})

        client = resume(token, 2)
        assert_receive {:resume, %{"vsn" => "2.0.0"} = params}
        refute Map.has_key?(params, "phx:resume")
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 1}}
        assert_receive %Message{event: "missed", payload: %{"n" => 1}}
        assert_receive %Message{event: "missed", payload: %{"n" => 2}}
        assert Process.whereis(:"room:a") == channel

        # the channel keeps working
        echo(client, %{"hi" => true})
        assert_receive %Message{event: "echo", payload: %{"hi" => true}}
        refute_received {:connect, _}
      end

      test "sends the messages the client did not receive again" do
        {client, token} = new_session()
        _channel = join(client, "room:a")
        drop(client)

        # the client lost the joined push
        _client = resume(token, 1)
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 1, "last" => 2}}
        assert_receive %Message{event: "joined"}
      end

      test "tells the client about the messages the session received" do
        {client, _token} = new_session()
        join(client, "room:a")
        assert_receive %Message{event: "phx_ack", payload: %{"seq" => 1}}

        WebsocketClient.send_event(client, "room:a", "echo", %{})
        assert_receive %Message{event: "phx_ack", payload: %{"seq" => 2}}
      end

      test "drops the messages the client acknowledged" do
        {client, token} = new_session()
        join(client, "room:a")
        session = session(token)
        assert :queue.len(:sys.get_state(session).out) == 2

        control(client, "phx_ack", %{ack: 2})
        Process.sleep(50)
        assert :queue.is_empty(:sys.get_state(session).out)
      end

      test "drops the messages of the previous connection the client sends again" do
        {client, token} = new_session()
        join(client, "room:a")
        session = session(token)
        drop(client)

        # the old connection delivers the echo late, after the client resumed
        client = resume(token, 2)
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 1}}
        frame = ~s(["11","9","room:a","echo",{"n":1}])
        send(session, {:pipe_in, self(), 2, {frame, :text}})
        assert_receive %Message{event: "echo", payload: %{"n" => 1}}

        # the client sends it again
        WebsocketClient.send(client, {:text, frame})
        echo(client, %{"n" => 2})
        assert_receive %Message{event: "echo", payload: %{"n" => 2}}
        refute_received %Message{event: "echo", payload: %{"n" => 1}}
      end

      test "stops the session when it rejects the resume" do
        {client, token} = new_session()
        channel = join(client, "room:a")
        ref = Process.monitor(channel)
        drop(client)

        resume(token, 2, %{"reject_resume" => "true"})
        assert_receive %Message{event: "phx_gone", payload: payload}
        refute Map.has_key?(payload, "code")
        assert_receive {:DOWN, ^ref, _, _, _}
      end

      test "tells the client when it cannot resume the session" do
        {client, token} = new_session()
        session = session(token)
        ref = Process.monitor(session)
        drop(client)

        # the session expires without a connection
        assert_receive {:DOWN, ^ref, _, _, {:shutdown, :inactive}}, 1000

        resume(token, 0)
        assert_receive %Message{event: "phx_gone"}

        resume("invalid", 0)
        assert_receive %Message{event: "phx_gone"}
      end

      test "requires the client to resume before sending messages" do
        client = connect(%{"phx:resumable" => "1", "phx:resume" => "1"})
        WebsocketClient.join(client, "room:a", %{})
        assert_receive %Message{event: "phx_gone"}
        refute_received {:connect, _}
      end

      test "replaces the connection the client gave up on" do
        {client, token} = new_session()
        join(client, "room:a")
        ref = Process.monitor(client)

        # the client resumes while the server still has the old connection
        _client = resume(token, 2)
        assert_receive %Message{event: "phx_resumed"}
        assert_receive {:DOWN, ^ref, _, _, _}
      end

      test "stops the session when the client closes it" do
        {client, _token} = new_session()
        channel = join(client, "room:a")
        ref = Process.monitor(channel)

        control(client, "phx_close", %{})
        assert_receive {:DOWN, ^ref, _, _, {:shutdown, :closed}}
      end

      test "closes normally when the socket is disconnected" do
        {client, _token} = new_session(%{"user_id" => "1"})
        join(client, "room:a")

        # like a WebSocket without a session, see Phoenix.Socket.id/1
        Endpoint.broadcast("user_sockets:1", "disconnect", %{})
        assert_receive %Message{event: "phx_gone", payload: %{"code" => 1000}}
      end

      test "closes the session when the client does not acknowledge messages" do
        {client, token} = new_session()
        join(client, "room:a")
        ref = Process.monitor(session(token))

        assert_receive {:DOWN, ^ref, _, _, {:shutdown, :unacknowledged}}, 1000
        assert_receive %Message{event: "phx_gone", payload: %{"code" => 1011}}
      end

      test "long polling resumes a WebSocket session" do
        {client, token} = new_session()
        channel = join(client, "room:a")
        drop(client)
        send(channel, {:push, "missed", %{}})

        body = poll(:get, token, %{"phx:ack" => "2", "phx:resume" => "1"})
        assert body["status"] == 200
        assert [%Message{event: "missed"}] = decode(body["messages"])
        assert body["last"] == 3
        assert_receive {:resume, _params}

        assert {_, %Phoenix.Socket{transport: :longpoll}} =
                 elem(:sys.get_state(session(token)).handler, 1)

        # the client sends the messages the WebSocket did not deliver, numbered
        # after the last one the session confirmed
        frame = ~s(["11","9","room:a","echo",{"n":1}])
        assert poll(:post, token, %{"phx:seq" => "2"}, frame)["status"] == 200
        assert poll(:post, token, %{"phx:seq" => "2"}, frame)["status"] == 200

        body = poll(:get, token, %{"phx:ack" => "3"})
        assert [%Message{event: "echo", payload: %{"n" => 1}}] = decode(body["messages"])
        assert Process.whereis(:"room:a") == channel
      end

      test "long polling takes over from a WebSocket the client gave up on" do
        {client, token} = new_session()
        join(client, "room:a")
        ref = Process.monitor(client)

        body = poll(:get, token, %{"phx:ack" => "2", "phx:resume" => "1"})
        assert body["status"] == 204
        assert_receive {:DOWN, ^ref, _, _, _}
        refute match?({:pipe, _, _}, :sys.get_state(session(token)).client)
      end

      test "answers heartbeats without numbering them" do
        {client, token} = new_session()
        :ok = WebsocketClient.send(client, {:text, ~s([null,"5","phoenix","heartbeat",{}])})

        assert_receive %Message{
          topic: "phoenix",
          event: "phx_reply",
          ref: "5",
          payload: %{"status" => "ok"}
        }

        # the session did not receive a numbered message, so the pipe does not confirm it
        refute_receive %Message{event: "phx_ack"}, 50

        join(client, "room:a")
        assert_receive %Message{event: "phx_ack", payload: %{"seq" => 1}}
        drop(client)

        # the client replays neither the heartbeat nor its reply
        _client = resume(token, 0)
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 1, "last" => 2}}
        assert_receive %Message{event: "phx_reply", topic: "room:a"}
        assert_receive %Message{event: "joined", topic: "room:a"}
        refute_receive %Message{topic: "phoenix", event: "phx_reply"}, 50
      end

      test "passes control frames to the socket without numbering them" do
        {client, token} = new_ping_session()

        WebsocketClient.send(client, {:ping, "123"})
        assert_receive {:pong, "123"}
        assert_receive {:text, "ping:123"}

        state = :sys.get_state(session(token))
        assert state.in_seq == 0
        assert state.out_seq == 1
      end

      test "does not number the control frames the socket sends" do
        {client, token} = new_ping_session()

        # the client answers the ping with a pong, which the socket answers with text
        WebsocketClient.send(client, {:text, "ping:abc"})
        assert_receive {:ping, "abc"}
        assert_receive {:text, "pong:abc"}

        state = :sys.get_state(session(token))
        assert state.in_seq == 1
        assert state.out_seq == 1
        assert [{1, :text, "pong:abc"}] = :queue.to_list(state.out)
      end

      test "long polling must resume a WebSocket session before it polls" do
        {client, token} = new_session()
        channel = join(client, "room:a")
        drop(client)
        send(channel, {:push, "missed", %{}})

        # with the token alone, also without the ack that older clients don't send
        assert poll(:get, token, %{"phx:ack" => "2"})["status"] == 410
        assert poll(:get, token, %{})["status"] == 410
        refute_received {:resume, _}

        # the session keeps the messages for its client
        body = poll(:get, token, %{"phx:ack" => "2", "phx:resume" => "1"})
        assert [%Message{event: "missed"}] = decode(body["messages"])
        assert_received {:resume, _}
      end

      test "long polling must resume a WebSocket session before it sends messages" do
        {client, token} = new_session()
        join(client, "room:a")

        # with the token alone, also without the seq that older clients don't send
        frame = ~s(["11","9","room:a","echo",{"from":"poll"}])
        assert poll(:post, token, %{"phx:seq" => "2"}, frame)["status"] == 410
        assert poll(:post, token, %{}, frame)["status"] == 410
        refute_received {:resume, _}

        # the session keeps running for the WebSocket and did not count the requests
        echo(client, %{"from" => "ws"})
        assert_receive %Message{event: "echo", payload: %{"from" => "ws"}}
        refute_received %Message{event: "echo"}
      end

      test "polls do not take or acknowledge the messages of a WebSocket" do
        {client, token} = new_session()
        channel = join(client, "room:a")
        send(channel, {:push, "new", %{}})
        assert_receive %Message{event: "new"}

        # a request that has the token but did not resume the session to long poll
        assert poll(:get, token, %{"phx:ack" => "3"})["status"] == 410

        # the session still keeps the message for the WebSocket
        drop(client)
        resume(token, 2)
        assert_receive %Message{event: "phx_resumed", payload: %{"last" => 3}}
        assert_receive %Message{event: "new"}
      end

      test "long polling must resume its session again after a WebSocket resumed it" do
        token = poll(:get, nil, %{})["token"]
        client = resume(token, 0)
        assert_receive %Message{event: "phx_resumed"}
        drop(client)

        assert poll(:get, token, %{"phx:ack" => "0"})["status"] == 410
      end

      test "long polling continues a WebSocket session with its own window" do
        client = connect(%{"phx:resumable" => "1"}, "/ws/windows")
        assert_receive %Message{event: "phx_session", payload: %{"token" => token}}
        join(client, "room:a")
        drop(client)

        # the session does not take a poll that waits for messages for inactivity
        resume = %{"phx:ack" => "2", "phx:resume" => "1"}
        assert poll(:get, token, resume, nil, "/ws/windows")["status"] == 204
        assert poll(:get, token, %{"phx:ack" => "2"}, nil, "/ws/windows")["status"] == 204
        assert Process.alive?(session(token))
      end

      test "long polling answers the poll that resumes without waiting for messages" do
        client = connect(%{"phx:resumable" => "1"}, "/ws/windows")
        assert_receive %Message{event: "phx_session", payload: %{"token" => token}}
        channel = join(client, "room:a")
        drop(client)

        # the client waits for the answer before it sends its messages
        resume = %{"phx:ack" => "2", "phx:resume" => "1"}
        {time, body} = :timer.tc(fn -> poll(:get, token, resume, nil, "/ws/windows") end)
        assert %{"status" => 204, "messages" => [], "last" => 2} = body
        assert time < 500_000

        # the next poll waits for messages
        task = Task.async(fn -> poll(:get, token, %{"phx:ack" => "2"}, nil, "/ws/windows") end)
        Process.sleep(50)
        send(channel, {:push, "new", %{}})
        assert [%Message{event: "new"}] = decode(Task.await(task)["messages"])
      end

      test "long polling sends binary messages in base64" do
        {client, token} = new_session()
        join(client, "room:a")
        drop(client)

        assert poll(:get, token, %{"phx:ack" => "2", "phx:resume" => "1"})["status"] == 204
        assert poll(:post, token, %{"phx:seq" => "2"}, ~s(["11","9","room:a","binary",{}]))
        body = poll(:get, token, %{"phx:ack" => "2"})
        assert ["base64:" <> encoded] = body["messages"]

        assert <<0, _join_ref_size, _topic_size, _event_size, rest::binary>> =
                 Base.decode64!(encoded)

        assert String.ends_with?(rest, <<1, 2, 3>>)
      end

      test "a WebSocket resumes a long polling session" do
        body = poll(:get, nil, %{})
        assert body["status"] == 410
        token = body["token"]

        join = ~s(["11","1","room:a","phx_join",{}])
        assert poll(:post, token, %{"phx:seq" => "1"}, join)["status"] == 200
        channel = Process.whereis(:"room:a")
        Process.sleep(50)

        # the client did not receive the join reply and the joined push
        resume(token, 0)
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 1}}
        assert_receive %Message{event: "phx_reply", topic: "room:a"}
        assert_receive %Message{event: "joined", topic: "room:a"}
        assert Process.whereis(:"room:a") == channel
      end

      test "a WebSocket does not resume the session of another token with the same pid" do
        {client, token} = new_session()
        channel = join(client, "room:a")
        session = session(token)
        attached = :sys.get_state(session).client
        forged = forge_token(token, fn {:v1, id, pid, _topic} -> {:v1, id, pid, "other"} end)

        _other = resume(forged, 0)
        assert_receive %Message{event: "phx_gone"}
        refute_received {:resume, _}

        # the session keeps its client
        assert :sys.get_state(session).client == attached
        echo(client, %{"still" => "here"})
        assert_receive %Message{event: "echo", payload: %{"still" => "here"}}
        assert Process.whereis(:"room:a") == channel
      end

      test "a WebSocket does not resume a session of an endpoint that restarted" do
        {_client, token} = new_session()
        forged = forge_token(token, fn {:v1, _id, pid, topic} -> {:v1, "old", pid, topic} end)

        resume(forged, 0)
        assert_receive %Message{event: "phx_gone"}
        refute_received {:resume, _}
      end

      test "does not start a session for clients that don't resume" do
        client = connect(%{})
        join(client, "room:a")
        refute_received %Message{event: "phx_session"}
      end

      test "does not start a session when the socket is not resumable" do
        client = connect(%{"phx:resumable" => "1"}, "/ws/plain")
        assert_receive {:connect, %{"vsn" => "2.0.0"}}
        join(client, "room:a")
        refute_received %Message{event: "phx_session"}
      end

      test "does not pass the resume params to the socket" do
        new_session()
        assert_receive {:connect, params}
        refute Map.has_key?(params, "phx:resumable")
      end

      test "preserves application params on sockets that did not opt in" do
        params = %{"resumable" => "1", "resume" => "1", "ack" => "2", "seq" => "3"}
        expected = Map.put(params, "vsn", "2.0.0")

        for path <- ["/ws", "/ws/plain"] do
          connect(params, path)
          assert_receive {:connect, ^expected}
        end
      end

      test "preserves application params when a WebSocket connects and resumes" do
        params = %{"resumable" => "1", "resume" => "1", "ack" => "2", "seq" => "3"}
        expected = Map.put(params, "vsn", "2.0.0")
        {client, token} = new_session(params)
        assert_received {:connect, ^expected}
        drop(client)

        resume(token, 0, params)
        assert_receive {:resume, ^expected}
        assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 0, "last" => 0}}
      end

      test "preserves application params and removes protocol params for long polling" do
        params = %{"resumable" => "1", "resume" => "1", "ack" => "2", "seq" => "3"}
        expected = Map.put(params, "vsn", "2.0.0")

        query = Map.merge(params, %{"phx:ack" => "0", "phx:seq" => "1", "phx:resume" => "1"})
        body = poll(:get, nil, query)
        assert body["status"] == 410
        assert_received {:connect, ^expected}

        body = poll(:get, body["token"], query)
        assert body["status"] == 204
        assert_received {:resume, ^expected}
      end

      test "starts a session when the :resumable function allows the connection" do
        client = connect(%{"phx:resumable" => "1", "user_id" => "1"}, "/ws/users")
        assert_receive %Message{event: "phx_session", payload: %{"token" => _}}

        # the function receives the same map as connect/1, followed by its arguments
        assert_received {:connect, params}
        assert_received {:resumable?, transport_info, :arg}
        assert %{endpoint: Endpoint, transport: :websocket, connect_info: %{}} = transport_info
        assert transport_info.params == params
        refute Map.has_key?(params, "phx:resumable")

        join(client, "room:a")
      end

      test "does not start a session when the :resumable function denies the connection" do
        client = connect(%{"phx:resumable" => "1"}, "/ws/users")
        assert_received {:connect, %{"vsn" => "2.0.0"}}
        assert_received {:resumable?, _transport_info, :arg}

        # the client connects like it does to a socket that is not resumable
        join(client, "room:a")
        refute_received %Message{event: "phx_session"}
      end

      test "does not invoke the :resumable function when a client resumes" do
        client = connect(%{"phx:resumable" => "1", "user_id" => "1"}, "/ws/users")
        assert_receive %Message{event: "phx_session", payload: %{"token" => token}}
        assert_received {:resumable?, _transport_info, :arg}
        channel = join(client, "room:a")
        drop(client)

        # the function denies connections without a user
        resume(token, 2, %{}, "/ws/users")
        assert_receive %Message{event: "phx_resumed"}
        assert_received {:resume, _params}
        refute_received {:resumable?, _transport_info, _arg}
        assert Process.whereis(:"room:a") == channel
      end

      test "does not invoke the :resumable function when the socket rejects the connection" do
        params = %{"vsn" => "2.0.0", "phx:resumable" => "1", "reject_connect" => "true"}
        url = "ws://127.0.0.1:#{@port}/ws/users/websocket?" <> URI.encode_query(params)

        assert {:error, %Mint.WebSocket.UpgradeFailureError{status_code: 403}} =
                 WebsocketClient.connect(self(), url, V2.JSONSerializer)

        refute_received {:resumable?, _transport_info, _arg}
      end

      test "raises when the :resumable function does not return a boolean" do
        # we call the endpoint ourselves, as the server logs the error after it responded
        params = %{"vsn" => "2.0.0", "phx:resumable" => "1", "user_id" => "invalid"}
        conn = Plug.Test.conn(:get, "/ws/users/websocket?" <> URI.encode_query(params))

        assert_raise ArgumentError, ~r/resumable\?\/2, given as :resumable, must return/, fn ->
          Endpoint.call(conn, [])
        end
      end
    end
  end
end
