defmodule Phoenix.Transports.SocketTest do
  use ExUnit.Case, async: true

  defmodule UserSocket do
    use Phoenix.Socket

    transport :websocket, Phoenix.Transports.WebSocket, timeout: 1234
    transport :longpoll, Phoenix.Transports.LongPoll

    def connect(_, socket), do: {:ok, socket}
    def id(_), do: nil
  end

  defmodule SpdyTransport do
    def default_config(), do: []
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
    {Phoenix.Transports.WebSocket, opts} = UserSocket.__transport__(:websocket)
    assert Enum.sort(opts) ==
      [compress: false,
       serializer: [{Phoenix.Socket.V1.JSONSerializer, parse_requirement!("~> 1.0.0")},
                    {Phoenix.Socket.V2.JSONSerializer, parse_requirement!("~> 2.0.0")}],
       timeout: 1234, transport_log: false]

    {Phoenix.Transports.LongPoll, opts} = UserSocket.__transport__(:longpoll)
    assert Enum.sort(opts) ==
      [crypto: [max_age: 1209600], pubsub_timeout_ms: 2000,
       serializer: [{Phoenix.Socket.V1.JSONSerializer, parse_requirement!("~> 1.0.0")},
                    {Phoenix.Socket.V2.JSONSerializer, parse_requirement!("~> 2.0.0")}],
       transport_log: false, window_ms: 10000]
  end

  defp parse_requirement!(requirement) do
    {:ok, req} = Version.parse_requirement(requirement)
    req
  end
end
