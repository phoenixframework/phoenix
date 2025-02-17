Code.require_file("../../support/websocket_client.exs", __DIR__)

defmodule Phoenix.Integration.WebSocketChannelsTest do
  # TODO: use parameterized tests once we require Elixir 1.18
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Socket.{V1, V2, Message}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5807

  Application.put_env(:phoenix, Endpoint,
    https: false,
    http: [port: @port],
    debug_errors: false,
    server: true,
    drainer: false,
    pubsub_server: __MODULE__,
    secret_key_base: String.duplicate("a", 64)
  )

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
      broadcast(socket, "user_entered", %{user: message["user"]})
      push(socket, "joined", Map.merge(%{status: "connected"}, socket.assigns))
      {:noreply, socket}
    end

    def handle_in("new_msg", message, socket) do
      broadcast!(socket, "new_msg", message)
      {:reply, :ok, socket}
    end

    def handle_in("boom", _message, _socket) do
      raise "boom"
    end

    def handle_in("binary_event", {:binary, data}, socket) do
      push(socket, "binary_event", {:binary, <<0, 1>>})
      {:reply, {:ok, {:binary, <<data::binary, 3, 4>>}}, socket}
    end

    def handle_out("new_msg", payload, socket) do
      push(socket, "new_msg", Map.put(payload, "transport", inspect(socket.transport)))
      {:noreply, socket}
    end

    def terminate(_reason, socket) do
      push(socket, "you_left", %{message: "bye!"})
      :ok
    end
  end

  defmodule CustomChannel do
    use GenServer, restart: :temporary

    def start_link(from) do
      GenServer.start_link(__MODULE__, from)
    end

    def init({_, _}) do
      {:ok, :init}
    end

    def handle_info({Phoenix.Channel, payload, from, socket}, :init) do
      case payload["action"] do
        "ok" ->
          GenServer.reply(from, {:ok, %{"action" => "ok"}})
          {:noreply, socket}

        "ignore" ->
          GenServer.reply(from, {:error, %{"action" => "ignore"}})
          send(self(), :stop)
          {:noreply, socket}

        "error" ->
          raise "oops"
      end
    end

    def handle_info(%Message{event: "close"}, socket) do
      send(socket.transport_pid, {:socket_close, self(), :shutdown})
      {:stop, :shutdown, socket}
    end

    def handle_info(:stop, socket) do
      {:stop, :shutdown, socket}
    end
  end

  defmodule UserSocketConnectInfo do
    use Phoenix.Socket, log: false

    channel "room:*", RoomChannel

    def connect(params, socket, connect_info) do
      unless params["logging"] == "enabled", do: Logger.disable(self())
      address = Tuple.to_list(connect_info.peer_data.address) |> Enum.join(".")

      connect_info =
        connect_info
        |> Map.update!(:peer_data, &Map.put(&1, :address, address))
        |> Map.update!(:trace_context_headers, &Map.new/1)
        |> Map.update!(:uri, &Map.from_struct/1)
        |> Map.update!(:x_headers, &Map.new/1)
        |> Map.update!(:sec_websocket_headers, &Map.new/1)

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

    def connect(%{"ratelimit" => "true"}, _socket) do
      {:error, :rate_limit}
    end

    def connect(params, socket) do
      unless params["logging"] == "enabled", do: Logger.disable(self())
      {:ok, assign(socket, :user_id, params["user_id"])}
    end

    def id(socket) do
      if id = socket.assigns.user_id, do: "user_sockets:#{id}"
    end

    def handle_error(conn, :rate_limit), do: Plug.Conn.send_resp(conn, 429, "Too many requests")
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    @session_config store: :cookie,
                    key: "_hello_key",
                    signing_salt: "change_me"

    socket "/ws", UserSocket,
      websocket: [
        check_origin: ["//example.com"],
        timeout: 200,
        error_handler: {UserSocket, :handle_error, []}
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
        connect_info: [
          :trace_context_headers,
          :x_headers,
          :peer_data,
          :uri,
          :user_agent,
          :sec_websocket_headers,
          session: @session_config,
          signing_salt: "salt",
        ]
      ]

    plug Plug.Session, @session_config
    plug :fetch_session
    plug Plug.CSRFProtection
    plug :put_session

    defp put_session(conn, _) do
      conn
      |> put_session(:from_session, "123")
      |> send_resp(200, Plug.CSRFProtection.get_csrf_token())
    end
  end

  setup %{adapter: adapter} do
    config = Application.get_env(:phoenix, Endpoint)
    Application.put_env(:phoenix, Endpoint, Keyword.merge(config, adapter: adapter))
    capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: __MODULE__})
    :ok
  end

  @endpoint Endpoint

  for %{adapter: adapter} <- [
        %{adapter: Bandit.PhoenixAdapter},
        %{adapter: Phoenix.Endpoint.Cowboy2Adapter}
      ] do
    for {serializer, vsn, join_ref} <- [
          {V1.JSONSerializer, "1.0.0", nil},
          {V2.JSONSerializer, "2.0.0", "11"}
        ] do
      @serializer serializer
      @vsn vsn
      @vsn_path "ws://127.0.0.1:#{@port}/ws/websocket?vsn=#{@vsn}"
      @join_ref join_ref

      describe "adapter: #{inspect(adapter)} - with #{vsn} serializer #{inspect(serializer)}" do
        @describetag adapter: adapter

        test "endpoint handles multiple mount segments" do
          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/admin/websocket?vsn=#{@vsn}",
              @serializer
            )

          WebsocketClient.join(sock, "room:admin-lobby1", %{})

          assert_receive %Message{
            event: "phx_reply",
            payload: %{"response" => %{}, "status" => "ok"},
            join_ref: @join_ref,
            ref: "1",
            topic: "room:admin-lobby1"
          }
        end

        test "join, leave, and event messages" do
          {:ok, sock} = WebsocketClient.connect(self(), @vsn_path, @serializer)
          lobby = lobby()
          WebsocketClient.join(sock, lobby, %{})

          assert_receive %Message{
            event: "phx_reply",
            join_ref: @join_ref,
            payload: %{"response" => %{}, "status" => "ok"},
            ref: "1",
            topic: ^lobby
          }

          assert_receive %Message{
            event: "joined",
            join_ref: @join_ref,
            payload: %{"status" => "connected", "user_id" => nil}
          }

          assert_receive %Message{
            event: "user_entered",
            payload: %{"user" => nil},
            join_ref: nil,
            ref: nil,
            topic: ^lobby
          }

          channel_pid = Process.whereis(String.to_atom(lobby))
          assert channel_pid
          assert Process.alive?(channel_pid)

          WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "hi!"})

          assert_receive %Message{
            event: "new_msg",
            payload: %{"transport" => ":websocket", "body" => "hi!"}
          }

          WebsocketClient.leave(sock, lobby, %{})
          assert_receive %Message{event: "you_left", payload: %{"message" => "bye!"}}
          assert_receive %Message{event: "phx_reply", payload: %{"status" => "ok"}}
          assert_receive %Message{event: "phx_close", payload: %{}}
          refute Process.alive?(channel_pid)

          WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "Should ignore"})
          refute_receive %Message{event: "new_msg"}

          assert_receive %Message{
            event: "phx_reply",
            payload: %{"response" => %{"reason" => "unmatched topic"}}
          }

          WebsocketClient.send_event(sock, lobby, "new_msg", %{body: "Should ignore"})
          refute_receive %Message{event: "new_msg"}
        end

        test "transport x_headers are extracted to the socket connect_info" do
          extra_headers = [{"x-application", "Phoenix"}]

          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer,
              extra_headers
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{"connect_info" => %{"x_headers" => %{"x-application" => "Phoenix"}}}
          }
        end

        test "transport sec-websocket-* headers are extracted to the socket connect_info" do
          extra_headers = [
            {"sec-websocket-protocol", "phoenix, 123"},
            {"sec-websocket-extensions", "permessage-deflate; client_max_window_bits=15"}
          ]

          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer,
              extra_headers
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{
                "sec_websocket_headers" => %{
                  "sec-websocket-protocol" => "phoenix, 123",
                  "sec-websocket-extensions" => "permessage-deflate; client_max_window_bits=15"
                }
              }
            }
          }
        end

        test "transport trace_context_headers are extracted to the socket connect_info" do
          extra_headers = [
            {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"},
            {"tracestate", "congo=t61rcWkgMzE"}
          ]

          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer,
              extra_headers
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{
                "trace_context_headers" => %{
                  "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
                  "tracestate" => "congo=t61rcWkgMzE"
                }
              }
            }
          }
        end

        test "transport peer_data is extracted to the socket connect_info" do
          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{
                "peer_data" => %{"address" => "127.0.0.1", "port" => _, "ssl_cert" => nil}
              }
            }
          }
        end

        test "transport uri is extracted to the socket connect_info" do
          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{
                "uri" => %{
                  "host" => "127.0.0.1",
                  "path" => "/ws/connect_info/websocket",
                  "query" => "vsn=#{@vsn}",
                  "scheme" => "http",
                  "port" => @port
                }
              }
            }
          }
        end

        test "transport user agent is extracted to the socket connect_info" do
          extra_headers = [{"user-agent", "foo/1.0"}]

          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer,
              extra_headers
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{
                "user_agent" => "foo/1.0"
              }
            }
          }
        end

        test "transport session is extracted to the socket connect_info" do
          import Phoenix.ConnTest
          path = "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}"

          # GET the cookie and CSRF token
          conn = get(build_conn(), "/")
          extra_headers = [{"cookie", "_hello_key=" <> conn.resp_cookies["_hello_key"].value}]
          csrf_token_query = "&_csrf_token=" <> URI.encode_www_form(conn.resp_body)

          # It works with headers and cookie
          {:ok, sock} =
            WebsocketClient.connect(self(), path <> csrf_token_query, @serializer, extra_headers)

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{
              "connect_info" => %{"session" => %{"from_session" => "123", "_csrf_token" => _}}
            }
          }

          # It doesn't work without headers
          {:ok, sock} = WebsocketClient.connect(self(), path <> csrf_token_query, @serializer)
          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{"connect_info" => %{"session" => nil}}
          }

          # It doesn't work with invalid csrf token
          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              path <> "&_csrf_token=bad",
              @serializer,
              extra_headers
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{"connect_info" => %{"session" => nil}}
          }
        end

        test "transport custom keywords are extracted to the socket connect_info" do
          {:ok, sock} =
            WebsocketClient.connect(
              self(),
              "ws://127.0.0.1:#{@port}/ws/connect_info/websocket?vsn=#{@vsn}",
              @serializer
            )

          WebsocketClient.join(sock, lobby(), %{})

          assert_receive %Message{
            event: "joined",
            payload: %{"connect_info" => %{"signing_salt" => "salt"}}
          }
        end

        test "logs user socket connect when enabled" do
          log =
            capture_log(fn ->
              {:ok, _} =
                WebsocketClient.connect(self(), "#{@vsn_path}&logging=enabled", @serializer)
            end)

          assert log =~ "CONNECTED TO Phoenix.Integration.WebSocketChannelsTest.UserSocket in "
          assert log =~ "  Transport: :websocket"
          assert log =~ "  Serializer: #{inspect(@serializer)}"
          assert log =~ "  Parameters: %{\"logging\" => \"enabled\", \"vsn\" => #{inspect(@vsn)}}"
        end

        test "does not log user socket connect when disabled" do
          log =
            capture_log(fn ->
              {:ok, _} = WebsocketClient.connect(self(), @vsn_path, @serializer)
            end)

          assert log == ""
        end

        test "logs and filter params on join and handle_in" do
          topic = "room:admin-lobby2"

          {:ok, sock} =
            WebsocketClient.connect(self(), "#{@vsn_path}&logging=enabled", @serializer)

          log =
            capture_log(fn ->
              WebsocketClient.join(sock, topic, %{"join" => "yes", "password" => "no"})

              assert_receive %Message{
                event: "phx_reply",
                join_ref: @join_ref,
                payload: %{"response" => %{}, "status" => "ok"},
                ref: "1",
                topic: "room:admin-lobby2"
              }
            end)

          assert log =~ "JOINED room:admin-lobby2 in "
          assert log =~ "Parameters: %{\"join\" => \"yes\", \"password\" => \"[FILTERED]\"}"

          log =
            capture_log(fn ->
              WebsocketClient.send_event(sock, topic, "new_msg", %{
                "in" => "yes",
                "password" => "no"
              })

              assert_receive %Message{event: "phx_reply", ref: "2"}
            end)

          assert log =~
                   "HANDLED new_msg INCOMING ON room:admin-lobby2 (Phoenix.Integration.WebSocketChannelsTest.RoomChannel)"

          assert log =~ "Parameters: %{\"in\" => \"yes\", \"password\" => \"[FILTERED]\"}"
        end

        test "sends phx_error if a channel server abnormally exits" do
          {:ok, sock} = WebsocketClient.connect(self(), @vsn_path, @serializer)

          lobby = lobby()
          WebsocketClient.join(sock, lobby, %{})

          assert_receive %Message{
            event: "phx_reply",
            ref: "1",
            payload: %{"response" => %{}, "status" => "ok"}
          }

          assert_receive %Message{event: "joined"}
          assert_receive %Message{event: "user_entered"}

          capture_log(fn ->
            WebsocketClient.send_event(sock, lobby, "boom", %{})
            assert_receive %Message{event: "phx_error", payload: %{}, topic: ^lobby}
          end)
        end

        test "channels are terminated if transport normally exits" do
          {:ok, sock} = WebsocketClient.connect(self(), @vsn_path, @serializer)

          lobby = lobby()
          WebsocketClient.join(sock, lobby, %{})

          assert_receive %Message{
            event: "phx_reply",
            ref: "1",
            payload: %{"response" => %{}, "status" => "ok"}
          }

          assert_receive %Message{event: "joined"}

          channel = Process.whereis(String.to_atom(lobby))
          assert channel
          Process.monitor(channel)
          WebsocketClient.close(sock)

          assert_receive {:DOWN, _, :process, ^channel, shutdown}
                         when shutdown in [
                                :shutdown,
                                {:shutdown, :closed},
                                {:shutdown, :local_closed}
                              ]
        end

        test "refuses websocket events that haven't joined" do
          {:ok, sock} = WebsocketClient.connect(self(), @vsn_path, @serializer)

          WebsocketClient.send_event(sock, lobby(), "new_msg", %{body: "hi!"})
          refute_receive %Message{event: "new_msg"}

          assert_receive %Message{
            event: "phx_reply",
            payload: %{"response" => %{"reason" => "unmatched topic"}}
          }

          WebsocketClient.send_event(sock, lobby(), "new_msg", %{body: "Should ignore"})
          refute_receive %Message{event: "new_msg"}
        end

        test "refuses unallowed origins" do
          capture_log(fn ->
            assert {:ok, _} =
                     WebsocketClient.connect(self(), @vsn_path, @serializer, [
                       {"origin", "https://example.com"}
                     ])

            assert {:error, %Mint.WebSocket.UpgradeFailureError{status_code: 403}} =
                     WebsocketClient.connect(self(), @vsn_path, @serializer, [
                       {"origin", "http://notallowed.com"}
                     ])
          end)
        end

        test "refuses connects that error with 403 response" do
          assert {:error, %Mint.WebSocket.UpgradeFailureError{status_code: 403}} =
                   WebsocketClient.connect(self(), "#{@vsn_path}&reject=true", @serializer)
        end

        test "refuses connects that error with custom error response" do
          assert {:error, %Mint.WebSocket.UpgradeFailureError{status_code: 429}} =
                   WebsocketClient.connect(self(), "#{@vsn_path}&ratelimit=true", @serializer)
        end

        test "shuts down when receiving disconnect broadcasts on socket's id" do
          {:ok, sock} = WebsocketClient.connect(self(), "#{@vsn_path}&user_id=1001", @serializer)

          WebsocketClient.join(sock, "room:wsdisconnect1", %{})

          assert_receive %Message{
            topic: "room:wsdisconnect1",
            event: "phx_reply",
            ref: "1",
            payload: %{"response" => %{}, "status" => "ok"}
          }

          WebsocketClient.join(sock, "room:wsdisconnect2", %{})

          assert_receive %Message{
            topic: "room:wsdisconnect2",
            event: "phx_reply",
            ref: "2",
            payload: %{"response" => %{}, "status" => "ok"}
          }

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
          # :shutdown for cowboy, {:shutdown, :closed} for cowboy 2, {:shutdown, :disconnected}
          # for bandit
          assert shutdown in [:shutdown, {:shutdown, :closed}, {:shutdown, :disconnected}]
          assert_receive {:DOWN, _, :process, ^chan2, shutdown}
          assert shutdown in [:shutdown, {:shutdown, :closed}, {:shutdown, :disconnected}]
        end

        test "duplicate join event closes existing channel" do
          {:ok, sock} = WebsocketClient.connect(self(), "#{@vsn_path}&user_id=1001", @serializer)
          WebsocketClient.join(sock, "room:joiner", %{})

          assert_receive %Message{
            topic: "room:joiner",
            event: "phx_reply",
            ref: "1",
            payload: %{"response" => %{}, "status" => "ok"}
          }

          WebsocketClient.join(sock, "room:joiner", %{})

          assert_receive %Message{
            topic: "room:joiner",
            event: "phx_reply",
            ref: "2",
            payload: %{"response" => %{}, "status" => "ok"}
          }
        end

        test "returns 403 when versions to not match" do
          assert capture_log(fn ->
                   url = "ws://127.0.0.1:#{@port}/ws/websocket?vsn=123.1.1"

                   assert {:error, %Mint.WebSocket.UpgradeFailureError{status_code: 403}} =
                            WebsocketClient.connect(self(), url, @serializer)
                 end) =~
                   "The client's requested transport version \"123.1.1\" does not match server's version"
        end

        test "shuts down if client goes quiet" do
          {:ok, socket} = WebsocketClient.connect(self(), @vsn_path, @serializer)
          Process.monitor(socket)
          WebsocketClient.send_heartbeat(socket)

          assert_receive %Message{
            event: "phx_reply",
            payload: %{"response" => %{}, "status" => "ok"},
            ref: "1",
            topic: "phoenix"
          }

          assert_receive {:DOWN, _, :process, ^socket, :normal}, 400
        end

        test "warns for unmatched topic" do
          {:ok, sock} =
            WebsocketClient.connect(self(), "#{@vsn_path}&logging=enabled", @serializer)

          log =
            capture_log(fn ->
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

          assert log =~
                   "Ignoring unmatched topic \"unmatched-topic\" in Phoenix.Integration.WebSocketChannelsTest.UserSocket"
        end
      end
    end

    # Those tests are not transport specific but for integration purposes
    # it is best to assert custom channels work throughout the whole stack,
    # compared to only testing the socket <-> channel communication. Which
    # is why test them under the latest websocket transport.
    describe "adapter: #{inspect(adapter)} - custom channels" do
      @describetag adapter: adapter
      @serializer V2.JSONSerializer
      @vsn "2.0.0"
      @vsn_path "ws://127.0.0.1:#{@port}/ws/websocket?vsn=#{@vsn}"

      test "join, ignore, error, and event messages" do
        {:ok, sock} = WebsocketClient.connect(self(), @vsn_path, @serializer)

        WebsocketClient.join(sock, "custom:ignore", %{"action" => "ignore"})

        assert_receive %Message{
          event: "phx_reply",
          join_ref: "11",
          payload: %{"response" => %{"action" => "ignore"}, "status" => "error"},
          ref: "1",
          topic: "custom:ignore"
        }

        WebsocketClient.join(sock, "custom:error", %{"action" => "error"})

        assert_receive %Message{
          event: "phx_reply",
          join_ref: "12",
          payload: %{"response" => %{"reason" => "join crashed"}, "status" => "error"},
          ref: "2",
          topic: "custom:error"
        }

        WebsocketClient.join(sock, "custom:ok", %{"action" => "ok"})

        assert_receive %Message{
          event: "phx_reply",
          join_ref: "13",
          payload: %{"response" => %{"action" => "ok"}, "status" => "ok"},
          ref: "3",
          topic: "custom:ok"
        }

        WebsocketClient.send_event(sock, "custom:ok", "close", %{body: "bye!"})
        assert_receive %Message{event: "phx_close", payload: %{}}
      end
    end

    describe "adapter: #{inspect(adapter)} - binary" do
      @describetag adapter: adapter
      @serializer V2.JSONSerializer
      @vsn "2.0.0"
      @join_ref "11"

      test "messages can be pushed and received" do
        topic = "room:bin"

        {:ok, socket} =
          WebsocketClient.connect(
            self(),
            "ws://127.0.0.1:#{@port}/ws/websocket?vsn=#{@vsn}",
            @serializer
          )

        WebsocketClient.join(socket, topic, %{})

        assert_receive %Message{
          event: "phx_reply",
          payload: %{"response" => %{}, "status" => "ok"},
          join_ref: @join_ref,
          ref: "1",
          topic: ^topic
        }

        WebsocketClient.send_event(socket, topic, "binary_event", {:binary, <<1, 2>>})

        assert_receive %Message{
          event: "phx_reply",
          payload: %{"response" => {:binary, <<1, 2, 3, 4>>}, "status" => "ok"},
          join_ref: @join_ref,
          ref: "2",
          topic: ^topic
        }

        assert_receive %Message{
          event: "binary_event",
          join_ref: @join_ref,
          payload: {:binary, <<0, 1>>}
        }
      end
    end
  end
end
