Code.require_file("../../support/websocket_client.exs", __DIR__)

defmodule Phoenix.Integration.WebSocketResumeTest do
  # TODO: use parameterized tests once we require Elixir 1.18
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
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
  end

  defmodule UserSocket do
    use Phoenix.Socket

    channel "room:*", RoomChannel

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
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket, websocket: [resumable: true, window_ms: 200]
    socket "/ws/plain", UserSocket, websocket: true
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
    client = connect(Map.put(params, "resumable", "1"))
    assert_receive %Message{topic: "phoenix", event: "phx_session", payload: %{"token" => token}}
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

  defp resume(token, ack, params \\ %{}) do
    client = connect(Map.merge(params, %{"resumable" => "1", "resume" => "1"}))
    control(client, "phx_resume", %{token: token, ack: ack})
    client
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
        refute Map.has_key?(params, "resume")
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
        assert_receive %Message{event: "phx_resumed"}
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
        client = connect(%{"resumable" => "1", "resume" => "1"})
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

      test "tells the client when the session stops" do
        {client, _token} = new_session(%{"user_id" => "1"})
        join(client, "room:a")

        Endpoint.broadcast("user_sockets:1", "disconnect", %{})
        assert_receive %Message{event: "phx_gone", payload: %{"code" => 1011}}
      end

      test "closes the session when the client does not acknowledge messages" do
        {client, token} = new_session()
        join(client, "room:a")
        ref = Process.monitor(session(token))

        assert_receive {:DOWN, ^ref, _, _, {:shutdown, :unacknowledged}}, 1000
        assert_receive %Message{event: "phx_gone"}
      end

      test "does not start a session for clients that don't resume" do
        client = connect(%{})
        join(client, "room:a")
        refute_received %Message{event: "phx_session"}
      end

      test "does not start a session when the socket is not resumable" do
        client = connect(%{"resumable" => "1"}, "/ws/plain")
        assert_receive {:connect, %{"vsn" => "2.0.0"}}
        join(client, "room:a")
        refute_received %Message{event: "phx_session"}
      end

      test "does not pass the resume params to the socket" do
        new_session()
        assert_receive {:connect, params}
        refute Map.has_key?(params, "resumable")
      end
    end
  end
end
