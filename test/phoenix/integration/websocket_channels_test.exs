Code.require_file "../../support/websocket_client.exs", __DIR__

defmodule Phoenix.Integration.WebSocketChannelsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Socket.{V1, V2, Message}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5807

  Application.put_env(:phoenix, Endpoint, [
    https: false,
    http: [port: @port],
    debug_errors: false,
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__]
  ])

  defp lobby do
    "room:lobby#{System.unique_integer()}"
  end

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

  defmodule CustomChannel do
    use GenServer

    def start_link(triplet) do
      GenServer.start_link(__MODULE__, triplet)
    end

    def init({payload, from, socket}) do
      case payload["action"] do
        "ok" ->
          GenServer.reply(from, %{"action" => "ok"})
          {:ok, socket}

        "ignore" ->
          GenServer.reply(from, %{"action" => "ignore"})
          :ignore

        "error" ->
          raise "oops"
      end
    end

    def handle_info(%Message{event: "close"}, socket) do
      send socket.transport_pid, {:socket_close, self(), :shutdown}
      {:stop, :shutdown, socket}
    end
  end

  defmodule UserSocketConnectInfo do
    use Phoenix.Socket, log: false

    channel "room:*", RoomChannel

    def connect(params, socket, connect_info) do
      unless params["logging"] == "enabled", do: Logger.disable(self())
      address = Tuple.to_list(connect_info.peer_data.address) |> Enum.join(".")
      uri = Map.from_struct(connect_info.uri)
      x_headers = Enum.into(connect_info.x_headers, %{})

      connect_info =
        connect_info
        |> update_in([:peer_data], &Map.put(&1, :address, address))
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
    channel "custom:*", CustomChannel

    def connect(%{"reject" => "true"}, _socket) do
      :error
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
      websocket: [
        check_origin: ["//example.com"],
        timeout: 200
      ]

    socket "/ws/admin", UserSocket,
      websocket: [
        check_origin: ["//example.com"],
        timeout: 200
      ]

    socket "/ws/connect_info", UserSocketConnectInfo,
      websocket: [
        check_origin: ["//example.com"],
        timeout: 200,
        connect_info: [:x_headers, :peer_data, :uri]
      ]

    socket "/ws/connect_info_custom", UserSocketConnectInfo,
      websocket: [
        check_origin: ["//example.com"],
        timeout: 200,
        connect_info: [:x_headers, :peer_data, :uri, signing_salt: "salt"]
      ]
  end

  setup_all do
    capture_log fn -> Endpoint.start_link() end
    :ok
  end

  for {serializer, vsn, join_ref} <- [{V1.JSONSerializer, "1.0.0", nil}, {V2.JSONSerializer, "2.0.0", "1"}] do
    @serializer serializer
    @vsn vsn
    @vsn_path "ws://127.0.0.1:#{@port}/ws/websocket?vsn=#{@vsn}"
    @join_ref join_ref

    describe "with #{vsn} serializer #{inspect serializer}" do
      test "endpoint handles multiple mount segments" do
        {:ok, sock} = WebsocketClient.start_link(self(), "ws://127.0.0.1:#{@port}/ws/admin/websocket?vsn=#{@vsn}", @serializer)
        WebsocketClient.join(sock, "room:admin-lobby1", %{})
        assert_receive %Message{event: "phx_reply",
                                payload: %{"response" => %{}, "status" => "ok"},
                                join_ref: @join_ref,
                                ref: "1", topic: "room:admin-lobby1"}
      end

      test "join, leave, and event messages" do
        {:ok, sock} = WebsocketClient.start_link(self(), @vsn_path, @serializer)
        lobby = lobby()
        WebsocketClient.join(sock, lobby, %{})

        assert_receive %Message{event: "phx_reply",
                                join_ref: @join_ref,
                                payload: %{"response" => %{}, "status" => "ok"},
                                ref: "1", topic: ^lobby}

        assert_receive %Message{event: "joined",
                                payload: %{"status" => "connected", "user_id" => nil}}
        assert_receive %Message{event: "user_entered",
                                payload: %{"user" => nil},
                                ref: nil, topic: ^lobby}

        channel_pid = Process.whereis(String.to_atom(lobby))
        assert channel_pid
        assert Process.alive?(channel_pid)

        WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "hi!"})
        assert_receive %Message{event: "new_msg", payload: %{"transport" => ":websocket", "body" => "hi!"}}

        WebsocketClient.leave(sock, lobby, %{})
        assert_receive %Message{event: "you_left", payload: %{"message" => "bye!"}}
        assert_receive %Message{event: "phx_reply", payload: %{"status" => "ok"}}
        assert_receive %Message{event: "phx_close", payload: %{}}
        refute Process.alive?(channel_pid)

        WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "Should ignore"})
        refute_receive %Message{event: "new_msg"}
        assert_receive %Message{event: "phx_reply", payload: %{"response" => %{"reason" => "unmatched topic"}}}

        WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "Should ignore"})
        refute_receive %Message{event: "new_msg"}
      end

      test "transport x_headers are extracted to the socket connect_info" do
        extra_headers = [{"x-application", "Phoenix"}]
        {:ok, sock} =
          WebsocketClient.start_link(
            self(),
            "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
            @serializer,
            extra_headers
          )

        WebsocketClient.join(sock, lobby(), %{})

        assert_receive %Message{event: "joined",
                                payload: %{"connect_info" =>
                                  %{"x_headers" =>
                                    %{"x-application" => "Phoenix"}}}}
      end

      test "transport peer_data is extracted to the socket connect_info" do
        {:ok, sock} =
          WebsocketClient.start_link(
            self(),
            "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
            @serializer
          )

        WebsocketClient.join(sock, lobby(), %{})

        assert_receive %Message{event: "joined",
                                payload: %{"connect_info" =>
                                  %{"peer_data" =>
                                    %{"address" => "127.0.0.1",
                                      "port" => _,
                                      "ssl_cert" => nil}}}}
      end

      test "transport uri is extracted to the socket connect_info" do
        {:ok, sock} =
          WebsocketClient.start_link(
            self(),
            "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
            @serializer
          )
        WebsocketClient.join(sock, lobby(), %{})

        assert_receive %Message{event: "joined",
                                payload: %{"connect_info" =>
                                  %{"uri" =>
                                    %{"host" => "127.0.0.1",
                                      "path" => "/ws/connect_info/websocket",
                                      "query" => "vsn=#{@vsn}",
                                      "scheme" => "http",
                                      "port" => 80}}}}
      end

      test "transport custom keywords are extracted to the socket connect_info" do
        {:ok, sock} =
          WebsocketClient.start_link(
            self(),
            "ws://127.0.0.1:#{@port}/ws/connect_info_custom/websocket?vsn=#{@vsn}",
            @serializer
          )
        WebsocketClient.join(sock, lobby(), %{})

        assert_receive %Message{
          event: "joined",
          payload: %{"connect_info" => %{"signing_salt" => "salt"}}
        }
      end

      test "logs user socket connect when enabled" do
        log = capture_log(fn ->
          {:ok, _} = WebsocketClient.start_link(self(), "#{@vsn_path}&logging=enabled", @serializer)
        end)
        assert log =~ "CONNECT #{inspect(UserSocket)}"
      end

      test "does not log user socket connect when disabled" do
        log = capture_log(fn ->
          {:ok, _} =
            WebsocketClient.start_link(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer
            )
        end)
        assert log == ""
      end

      test "logs and filter params on join and handle_in" do
        topic = "room:admin-lobby2"
        {:ok, sock} = WebsocketClient.start_link(self(), "#{@vsn_path}&logging=enabled", @serializer)
        log = capture_log fn ->
          WebsocketClient.join(sock, topic, %{"join" => "yes", "password" => "no"})
          assert_receive %Message{event: "phx_reply",
                                  join_ref: @join_ref,
                                  payload: %{"response" => %{}, "status" => "ok"},
                                  ref: "1", topic: "room:admin-lobby2"}
        end
        assert log =~ "Parameters: %{\"join\" => \"yes\", \"password\" => \"[FILTERED]\"}"

        log = capture_log fn ->
          WebsocketClient.send_event(sock, topic, "new_msg", %{"in" => "yes", "password" => "no"})
          assert_receive %Message{event: "phx_reply", ref: "2"}
        end
        assert log =~ "Parameters: %{\"in\" => \"yes\", \"password\" => \"[FILTERED]\"}"
      end

      test "sends phx_error if a channel server abnormally exits" do
        {:ok, sock} = WebsocketClient.start_link(self(), @vsn_path, @serializer)

        lobby = lobby()
        WebsocketClient.join(sock, lobby, %{})
        assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
        assert_receive %Message{event: "joined"}
        assert_receive %Message{event: "user_entered"}

        capture_log fn ->
          WebsocketClient.send_event(sock, lobby, "boom", %{})
          assert_receive %Message{event: "phx_error", payload: %{}, topic: ^lobby}
        end
      end

      test "channels are terminated if transport normally exits" do
        {:ok, sock} = WebsocketClient.start_link(self(), @vsn_path, @serializer)

        lobby = lobby()
        WebsocketClient.join(sock, lobby, %{})
        assert_receive %Message{event: "phx_reply", ref: "1", payload: %{"response" => %{}, "status" => "ok"}}
        assert_receive %Message{event: "joined"}

        channel = Process.whereis(String.to_atom(lobby))
        assert channel
        Process.monitor(channel)
        WebsocketClient.close(sock)

        assert_receive {:DOWN, _, :process, ^channel, shutdown}
                       when shutdown in [:shutdown, {:shutdown, :closed}]
      end

      test "refuses websocket events that haven't joined" do
        {:ok, sock} = WebsocketClient.start_link(self(), @vsn_path, @serializer)

        WebsocketClient.send_event(sock, lobby(), "new_msg", %{body: "hi!"})
        refute_receive %Message{event: "new_msg"}
        assert_receive %Message{event: "phx_reply", payload: %{"response" => %{"reason" => "unmatched topic"}}}

        WebsocketClient.send_event(sock, lobby(), "new_msg", %{body: "Should ignore"})
        refute_receive %Message{event: "new_msg"}
      end

      test "refuses unallowed origins" do
        capture_log fn ->
          assert {:ok, _} =
            WebsocketClient.start_link(self(), @vsn_path, @serializer,
                                              [{"origin", "https://example.com"}])
          assert {:error, {403, _}} =
            WebsocketClient.start_link(self(), @vsn_path, @serializer,
                                            [{"origin", "http://notallowed.com"}])
        end
      end

      test "refuses connects that error with 403 response" do
        assert WebsocketClient.start_link(self(), "#{@vsn_path}&reject=true", @serializer) ==
              {:error, {403, "Forbidden"}}
      end

      test "shuts down when receiving disconnect broadcasts on socket's id" do
        {:ok, sock} = WebsocketClient.start_link(self(), "#{@vsn_path}&user_id=1001", @serializer)

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
        assert_receive {:DOWN, _, :process, ^chan1, shutdown}
        #shutdown for cowboy, {:shutdown, :closed} for cowboy 2
        assert shutdown in [:shutdown, {:shutdown, :closed}]
        assert_receive {:DOWN, _, :process, ^chan2, shutdown}
        assert shutdown in [:shutdown, {:shutdown, :closed}]
      end

      test "duplicate join event closes existing channel" do
        {:ok, sock} = WebsocketClient.start_link(self(), "#{@vsn_path}&user_id=1001", @serializer)
        WebsocketClient.join(sock, "room:joiner", %{})
        assert_receive %Message{topic: "room:joiner", event: "phx_reply",
                                ref: "1", payload: %{"response" => %{}, "status" => "ok"}}

        WebsocketClient.join(sock, "room:joiner", %{})
        assert_receive %Message{topic: "room:joiner", event: "phx_reply",
                                ref: "2", payload: %{"response" => %{}, "status" => "ok"}}
      end

      test "returns 403 when versions to not match" do
        assert capture_log(fn ->
          url = "ws://127.0.0.1:#{@port}/ws/websocket?vsn=123.1.1"
          assert WebsocketClient.start_link(self(), url,  @serializer) ==
                   {:error, {403, "Forbidden"}}
        end) =~ "The client's requested transport version \"123.1.1\" does not match server's version"
      end

      test "shuts down if client goes quiet" do
        {:ok, socket} = WebsocketClient.start_link(self(), @vsn_path, @serializer)
        Process.monitor(socket)
        WebsocketClient.send_heartbeat(socket)
        assert_receive %Message{event: "phx_reply",
                                payload: %{"response" => %{}, "status" => "ok"},
                                ref: "1", topic: "phoenix"}

        assert_receive {:DOWN, _, :process, ^socket, :normal}, 400
      end

      test "warns for unmatched topic" do
        {:ok, sock} = WebsocketClient.start_link(self(), "#{@vsn_path}&logging=enabled", @serializer)
        log = capture_log(fn ->
          WebsocketClient.join(sock, "unmatched-topic", %{})
          assert_receive %Message{
            event: "phx_reply",
            ref: "1",
            topic: "unmatched-topic",
            join_ref: nil,
            payload: %{
              "status" => "error",
              "response" => %{"reason" => "unmatched topic"}
            }
          }
        end)
        assert log =~ "[warn]  Ignoring unmatched topic \"unmatched-topic\" in Phoenix.Integration.WebSocketChannelsTest.UserSocket"
      end
    end
  end

  # Those tests are not transport specific but for integration purposes
  # it is best to assert custom channels work throughout the whole stack,
  # compared to only testing the socket <-> channel communication. Which
  # is why test them under the latest websocket transport.
  describe "custom channels" do
    @serializer V2.JSONSerializer
    @vsn "2.0.0"
    @vsn_path "ws://127.0.0.1:#{@port}/ws/websocket?vsn=#{@vsn}"

    test "join, ignore, error, and event messages" do
      {:ok, sock} = WebsocketClient.start_link(self(), @vsn_path, @serializer)

      WebsocketClient.join(sock, "custom:ignore", %{"action" => "ignore"})

      assert_receive %Message{event: "phx_reply",
                              join_ref: "1",
                              payload: %{"response" => %{"action" => "ignore"}, "status" => "error"},
                              ref: "1",
                              topic: "custom:ignore"}


      WebsocketClient.join(sock, "custom:error", %{"action" => "error"})

      assert_receive %Message{event: "phx_reply",
                              join_ref: "2",
                              payload: %{"response" => %{"reason" => "join crashed"}, "status" => "error"},
                              ref: "2",
                              topic: "custom:error"}

      WebsocketClient.join(sock, "custom:ok", %{"action" => "ok"})

      assert_receive %Message{event: "phx_reply",
                              join_ref: "3",
                              payload: %{"response" => %{"action" => "ok"}, "status" => "ok"},
                              ref: "3",
                              topic: "custom:ok"}

      WebsocketClient.send_event(sock, "custom:ok", "close", %{body: "bye!"})
      assert_receive %Message{event: "phx_close", payload: %{}}
    end
  end
end
