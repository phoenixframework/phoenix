Code.require_file("../../support/websocket_client.exs", __DIR__)
Code.require_file("../../support/http_client.exs", __DIR__)

defmodule Phoenix.Integration.DetachedSessionTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Phoenix.Integration.{HTTPClient, WebsocketClient}
  alias Phoenix.Socket.{Message, V2}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5910

  @session_config [store: :cookie, key: "_detached_key", signing_salt: "detached"]

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

    def join(_topic, %{"reject" => true}, _socket), do: {:error, %{reason: "rejected"}}

    # a payload of the server, which is not serialized
    def join(_topic, %{"notify" => {pid, ref}}, socket) when is_pid(pid) do
      send(pid, {ref, :rendered, "<div>"})
      {:ok, socket}
    end

    def join(topic, payload, socket) do
      Process.register(self(), String.to_atom(topic))
      send(self(), :after_join)
      {:ok, %{payload: payload, transport: inspect(socket.transport)}, socket}
    end

    def handle_info(:after_join, socket) do
      push(socket, "joined", %{})
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

    def connect(params, socket, connect_info) do
      send(Process.whereis(:detached_test), {:connect, params, socket, connect_info})

      case connect_info.session do
        %{"reject" => true} -> :error
        session -> {:ok, assign(socket, :user_id, session && session["user_id"])}
      end
    end

    def resume(%{"reject_resume" => "true"}, _socket, _connect_info), do: :error

    def resume(params, socket, _connect_info) do
      send(Process.whereis(:detached_test), {:resume, params, socket.transport})
      {:ok, socket}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end

    def resumable?(%{connect_info: %{session: session}}) do
      is_map(session) and Map.has_key?(session, "user_id")
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    @session_config [store: :cookie, key: "_detached_key", signing_salt: "detached"]

    socket "/ws", UserSocket,
      websocket: [resumable: true, window_ms: 200, connect_info: [:uri, session: @session_config]],
      longpoll: [window_ms: 200, pubsub_timeout_ms: 200, connect_info: [session: @session_config]]

    socket "/ws/plain", UserSocket, websocket: [connect_info: [session: @session_config]]

    socket "/ws/longpoll", UserSocket,
      websocket: false,
      longpoll: [window_ms: 200, pubsub_timeout_ms: 200, connect_info: [session: @session_config]]

    socket "/ws/users", UserSocket,
      websocket: [
        resumable: {UserSocket, :resumable?, []},
        window_ms: 200,
        connect_info: [session: @session_config]
      ]
  end

  setup do
    Process.register(self(), :detached_test)
    capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: __MODULE__})
    :ok
  end

  # the request of a page, with the session of its cookie
  defp page_conn(session \\ %{"user_id" => "1"}) do
    Plug.Test.conn(:get, "https://example.com/page")
    |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
    |> Plug.Test.init_test_session(session)
  end

  defp attach(token, ack \\ 0, params \\ %{}) do
    query =
      URI.encode_query(
        Map.merge(%{"vsn" => "2.0.0", "phx:resumable" => "1", "phx:resume" => "1"}, params)
      )

    url = "ws://127.0.0.1:#{@port}/ws/websocket?" <> query
    {:ok, client} = WebsocketClient.connect(self(), url, V2.JSONSerializer)

    json =
      Phoenix.json_library().encode!([
        nil,
        nil,
        "phoenix",
        "phx_resume",
        %{token: token, ack: ack}
      ])

    :ok = WebsocketClient.send(client, {:text, json})
    client
  end

  defp poll(method, token, params, path, body \\ nil) do
    query = URI.encode_query(Map.merge(%{"vsn" => "2.0.0"}, params))
    url = "http://127.0.0.1:#{@port}#{path}/longpoll?" <> query
    headers = %{"x-phoenix-longpoll-token" => token, "content-type" => "application/x-ndjson"}
    {:ok, resp} = HTTPClient.request(method, url, headers, body || "")
    Phoenix.json_library().decode!(resp.body)
  end

  defp decode(messages) do
    for message <- messages, do: V2.JSONSerializer.decode!(message, opcode: :text)
  end

  test "joins channels before a WebSocket attaches to the session" do
    assert {:ok, session, token} = Phoenix.Socket.start_detached(page_conn(), "/ws")

    assert_receive {:connect, %{"vsn" => "2.0.0"}, %Phoenix.Socket{transport: :detached},
                    connect_info}

    assert connect_info.session == %{"user_id" => "1"}
    assert connect_info.uri.host == "example.com"

    assert {:ok, join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{"n" => 1})
    channel = Process.whereis(:"room:a")
    send(channel, {:push, "before_attach", %{}})

    client = attach(token)
    assert_receive {:resume, %{"vsn" => "2.0.0"}, :websocket}
    assert_receive %Message{event: "phx_resumed", payload: %{"seq" => 0, "last" => 3}}

    assert_receive %Message{
      event: "phx_reply",
      topic: "room:a",
      ref: ^join_ref,
      join_ref: ^join_ref,
      payload: %{
        "status" => "ok",
        "response" => %{"payload" => %{"n" => 1}, "transport" => ":detached"}
      }
    }

    assert_receive %Message{event: "joined", topic: "room:a", join_ref: ^join_ref}
    assert_receive %Message{event: "before_attach", topic: "room:a", join_ref: ^join_ref}

    # the client sends with the join ref of the server
    json = Phoenix.json_library().encode!([join_ref, "1", "room:a", "echo", %{"hi" => true}])
    :ok = WebsocketClient.send(client, {:text, json})
    assert_receive %Message{event: "echo", payload: %{"hi" => true}}
    assert Process.whereis(:"room:a") == channel
  end

  test "long polling attaches to the session" do
    assert {:ok, session, token} = Phoenix.Socket.start_detached(page_conn(), "/ws/longpoll")
    assert {:ok, join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{})

    body = poll(:get, token, %{"phx:ack" => "0", "phx:resume" => "1"}, "/ws/longpoll")
    assert body["status"] == 200
    assert_receive {:resume, _params, :longpoll}

    assert [
             %Message{event: "phx_reply", ref: ^join_ref, payload: %{"status" => "ok"}},
             %Message{event: "joined"}
           ] = decode(body["messages"])
  end

  test "long polling must attach before it polls" do
    assert {:ok, _session, token} = Phoenix.Socket.start_detached(page_conn(), "/ws/longpoll")
    assert poll(:get, token, %{"phx:ack" => "0"}, "/ws/longpoll")["status"] == 410
  end

  test "stops the session when it rejects the client" do
    assert {:ok, session, token} = Phoenix.Socket.start_detached(page_conn(), "/ws")
    ref = Process.monitor(session)
    assert {:ok, _join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{})
    channel = Process.monitor(Process.whereis(:"room:a"))

    _client = attach(token, 0, %{"reject_resume" => "true"})
    assert_receive %Message{event: "phx_gone"}
    assert_receive {:DOWN, ^ref, _, _, _}
    assert_receive {:DOWN, ^channel, _, _, _}
  end

  test "stops the session when no client attaches within its window" do
    assert {:ok, session, _token} =
             Phoenix.Socket.start_detached(page_conn(), "/ws", window_ms: 20)

    ref = Process.monitor(session)
    assert {:ok, _join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{})
    channel = Process.monitor(Process.whereis(:"room:a"))
    assert_receive {:DOWN, ^ref, _, _, {:shutdown, :inactive}}, 200
    assert_receive {:DOWN, ^channel, _, _, _}
  end

  test "stops a session" do
    assert {:ok, session, _token} = Phoenix.Socket.start_detached(page_conn(), "/ws")
    assert {:ok, _join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{})
    channel = Process.monitor(Process.whereis(:"room:a"))
    assert :ok = Phoenix.Socket.stop_detached(session)
    refute Process.alive?(session)
    assert_receive {:DOWN, ^channel, _, _, _}
    assert :ok = Phoenix.Socket.stop_detached(session)
  end

  test "returns the errors of joins" do
    assert {:ok, session, _token} = Phoenix.Socket.start_detached(page_conn(), "/ws")

    assert {:error, %{reason: "rejected"}} =
             Phoenix.Socket.join_detached(session, "room:a", %{"reject" => true})

    assert {:error, %{reason: "unmatched topic"}} =
             Phoenix.Socket.join_detached(session, "unknown", %{})

    assert {:ok, _join_ref} = Phoenix.Socket.join_detached(session, "room:a", %{})

    assert {:error, %{reason: "already joined"}} =
             Phoenix.Socket.join_detached(session, "room:a", %{})
  end

  test "passes payloads that are not serialized to the channel" do
    assert {:ok, session, _token} = Phoenix.Socket.start_detached(page_conn(), "/ws")
    ref = make_ref()

    assert {:ok, _join_ref} =
             Phoenix.Socket.join_detached(session, "room:a", %{"notify" => {self(), ref}})

    assert_received {^ref, :rendered, "<div>"}
  end

  test "requires a conn that went through an endpoint" do
    assert_raise ArgumentError, ~r/requires a conn that went through an endpoint/, fn ->
      Phoenix.Socket.start_detached(Plug.Test.conn(:get, "/"), "/ws")
    end
  end

  test "does not start a session when the socket rejects the connection" do
    assert {:error, :rejected} =
             Phoenix.Socket.start_detached(page_conn(%{"reject" => true}), "/ws")
  end

  test "does not start a session for a WebSocket that is not resumable" do
    assert {:error, :not_resumable} = Phoenix.Socket.start_detached(page_conn(), "/ws/plain")
    refute_received {:connect, _, _, _}
  end

  test "lets the :resumable function decide" do
    assert {:ok, _session, _token} = Phoenix.Socket.start_detached(page_conn(), "/ws/users")
    assert {:error, :not_resumable} = Phoenix.Socket.start_detached(page_conn(%{}), "/ws/users")
  end

  test "does not start a session without a socket at the path" do
    assert {:error, :no_socket} = Phoenix.Socket.start_detached(page_conn(), "/unknown")
  end

  test "uses the session of the cookie when the request did not fetch it" do
    cookie_conn =
      Plug.Test.conn(:get, "/page")
      |> Map.put(:secret_key_base, Endpoint.config(:secret_key_base))
      |> Plug.Session.call(Plug.Session.init(@session_config))
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.put_session("user_id", "3")
      |> Plug.Conn.send_resp(200, "")

    cookie = cookie_conn.resp_cookies["_detached_key"].value

    # a request with a session cookie, which it did not fetch
    conn =
      Plug.Test.conn(:get, "/page")
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Plug.Test.put_req_cookie("_detached_key", cookie)

    assert {:ok, _session, _token} = Phoenix.Socket.start_detached(conn, "/ws")
    assert_receive {:connect, _params, _socket, %{session: %{"user_id" => "3"}}}
  end
end
