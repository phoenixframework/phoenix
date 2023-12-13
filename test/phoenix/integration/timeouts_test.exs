Code.require_file("../../support/websocket_client.exs", __DIR__)

defmodule Phoenix.Integration.TimeoutsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
  alias Phoenix.Socket.{V2, Message}
  alias __MODULE__.Endpoint

  @port 5807

  Application.put_env(:phoenix, Endpoint,
    https: false,
    http: [port: @port],
    debug_errors: false,
    server: true,
    pubsub_server: __MODULE__,
    secret_key_base: String.duplicate("a", 64)
  )

  defmodule TestChannel do
    use Phoenix.Channel

    def join(_topic, message, socket) do
      case Map.get(message, "sleep") do
        nil ->
          :noop

        sleep when is_integer(sleep) ->
          Process.sleep(sleep)
      end

      {:ok, socket}
    end
  end

  defmodule TestSocket do
    use Phoenix.Socket, log: false

    channel("test:*", TestChannel)

    def connect(_params, socket, _connect_info) do
      {:ok, socket}
    end

    def id(_socket), do: "123"
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket("/ws", TestSocket,
      websocket: [
        timeout: 5000
      ]
    )
  end

  setup_all do
    capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: __MODULE__})
    :ok
  end

  test "slow join doesn't prevent heartbeat replies" do
    # given
    {:ok, socket} =
      WebsocketClient.connect(
        self(),
        "ws://127.0.0.1:#{@port}/ws/websocket?vsn=2.0.0",
        V2.JSONSerializer
      )

    WebsocketClient.join(socket, "test:123", %{"sleep" => 2000})

    # when
    WebsocketClient.send_heartbeat(socket)

    # then
    # receive heartbeat reply
    assert_receive %Message{
      event: "phx_reply",
      payload: %{"response" => %{}, "status" => "ok"},
      ref: "2",
      topic: "phoenix",
      join_ref: nil
    }

    # receive join reply
    assert_receive %Message{
                     event: "phx_reply",
                     payload: %{"response" => %{}, "status" => "ok"},
                     ref: "1",
                     topic: "test:123",
                     join_ref: <<_::binary>>
                   },
                   3000
  end

  test "connection is closed if join takes longer than socket timeout" do
    # given
    {:ok, socket} =
      WebsocketClient.connect(
        self(),
        "ws://127.0.0.1:#{@port}/ws/websocket?vsn=2.0.0",
        V2.JSONSerializer
      )

    ref = Process.monitor(socket)

    # when
    WebsocketClient.join(socket, "test:123", %{"sleep" => 6000})

    # then
    assert_receive {:DOWN, ^ref, :process, ^socket, _reason}, 5100
  end

  # leave on a join in progress cancels the join and allows to join again
end
