defmodule Phoenix.Transports.WebTransport.HandlerTest do
  use ExUnit.Case, async: false

  alias Phoenix.Transports.WebTransport.Handler

  defmodule TestEndpoint do
    def config(:code_reloader), do: false
    def config(:check_origin), do: false
    def config(:secret_key_base), do: String.duplicate("a", 64)
    def config(_key), do: nil
  end

  defmodule CaptureSocket do
    def connect(config) do
      send(self(), {:connect_info, config.connect_info})
      {:ok, %{}}
    end

    def init(state), do: {:ok, state}
    def handle_in(_message, state), do: {:ok, state}
    def handle_info(_message, state), do: {:ok, state}
    def terminate(_reason, _state), do: :ok
  end

  defmodule PushSocket do
    def connect(_config), do: {:ok, %{}}
    def init(state), do: {:ok, state}
    def handle_in(_message, state), do: {:ok, state}
    def handle_info(:push, state), do: {:push, {:text, "hello"}, state}
    def handle_info(_message, state), do: {:ok, state}
    def terminate(_reason, _state), do: :ok
  end

  defmodule BinaryPushSocket do
    def connect(_config), do: {:ok, %{}}
    def init(state), do: {:ok, state}
    def handle_in(_message, state), do: {:ok, state}
    def handle_info(:push_binary, state), do: {:push, {:binary, <<1, 2, 3>>}, state}
    def handle_info(_message, state), do: {:ok, state}
    def terminate(_reason, _state), do: :ok
  end

  setup do
    :ets.new(TestEndpoint, [:named_table, :public, :set])
    :ok
  end

  test "init includes peer_data in connect_info without crashing" do
    req = %{
      method: "CONNECT",
      version: :"HTTP/3",
      scheme: :https,
      host: "example.com",
      port: 443,
      path: "/socket/webtransport",
      qs: "vsn=2.0.0",
      peer: {{127, 0, 0, 1}, 1234},
      headers: %{},
      bindings: %{}
    }

    assert {:cowboy_webtransport, ^req, _state, _opts} =
             Handler.init(
               req,
               {TestEndpoint, CaptureSocket, [check_origin: false, connect_info: [:peer_data]]}
             )

    assert_receive {:connect_info,
                    %{peer_data: %{address: {127, 0, 0, 1}, port: 1234, ssl_cert: nil}}}
  end

  test "stream_data rejects binary frame type in parser" do
    state = %Handler{handler: CaptureSocket, socket_state: %{}, stream_id: 1}
    frame = <<1, 0, 0, 0, 1, 1>>

    assert {[{:close, 0, reason}], _state} =
             Handler.webtransport_handle({:stream_data, 1, :nofin, frame}, state)

    assert reason =~ "invalid_type"
  end

  test "webtransport_info closes when pending frame buffer limit is exceeded" do
    state = %Handler{handler: PushSocket, socket_state: %{}, max_pending_bytes: 4}

    assert {[{:close, 0, "pending frame buffer exceeded"}], _state} =
             Handler.webtransport_info(:push, state)
  end

  test "close_initiated does not trigger socket drain path" do
    state = %Handler{handler: PushSocket, socket_state: %{}}
    assert {[], ^state} = Handler.webtransport_handle(:close_initiated, state)
  end

  test "extra stream_open events are ignored" do
    state = %Handler{handler: PushSocket, socket_state: %{}, stream_id: 1}
    assert {[], ^state} = Handler.webtransport_handle({:stream_open, 2, :unidi}, state)
  end

  test "binary pushes are skipped without closing session" do
    state = %Handler{handler: BinaryPushSocket, socket_state: %{}}
    assert {[], %Handler{} = next_state} = Handler.webtransport_info(:push_binary, state)
    assert next_state.socket_state == %{}
  end
end
