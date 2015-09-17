defmodule Phoenix.SocketTest do
  use ExUnit.Case, async: true

  import Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.InvalidMessageError

  defmodule UserSocket do
    use Phoenix.Socket

    transport :websocket, Phoenix.Transports.WebSocket,
      timeout: 1234
    transport :longpoll, Phoenix.Transports.LongPoll

    def connect(_, socket), do: {:ok, socket}
    def id(_), do: nil
  end

  defmodule SpdyTransport do
    def default_config(), do: []
  end

  test "from_map! converts a map with string keys into a %Message{}" do
    msg = Message.from_map!(%{"topic" => "c", "event" => "e", "payload" => "", "ref" => "r"})
    assert msg == %Message{topic: "c", event: "e", payload: "", ref: "r"}
  end

  test "from_map! raises InvalidMessageError when any required key" do
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"event" => "e", "payload" => "", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "payload" => "", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "event" => "e", "ref" => "r"})
    end
    assert_raise InvalidMessageError, fn ->
      Message.from_map!(%{"topic" => "c", "event" => "e"})
    end
  end

  test "assigning to socket" do
    socket = %Phoenix.Socket{}
    assert socket.assigns[:foo] == nil
    socket = assign(socket, :foo, :bar)
    assert socket.assigns[:foo] == :bar
  end

  test "duplicate transports raises" do
    assert_raise ArgumentError, ~r/duplicate transports/, fn ->
      defmodule MySocket do
        use Phoenix.Socket
        transport :websocket, Phoenix.Transports.WebSocket
        transport :websocket, SpdyTransport
        def connect(_, socket), do: {:ok, socket}
        def id(_), do: nil
      end
    end
  end

  test "__transports__" do
    assert %{longpoll: {Phoenix.Transports.LongPoll, _},
             websocket: {Phoenix.Transports.WebSocket, _}} = UserSocket.__transports__()
  end

  test "transport config is exposted and merged with prior registrations" do
    ws = {Phoenix.Transports.WebSocket,
      [timeout: 1234, serializer: Phoenix.Transports.WebSocketSerializer, transport_log: false, heartbeat: 30_000]}

    lp = {Phoenix.Transports.LongPoll,
      [window_ms: 10000, pubsub_timeout_ms: 2000, serializer: Phoenix.Transports.LongPollSerializer,
       transport_log: false, crypto: [max_age: 1209600]]}

    assert UserSocket.__transport__(:websocket) == ws
    assert UserSocket.__transport__(:longpoll) == lp
  end
end
