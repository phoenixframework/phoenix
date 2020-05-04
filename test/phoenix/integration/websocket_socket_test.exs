Code.require_file("../../support/websocket_client.exs", __DIR__)

defmodule Phoenix.Integration.WebSocketTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Phoenix.Integration.WebsocketClient
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5907
  @path "ws://127.0.0.1:#{@port}/ws/websocket"

  Application.put_env(
    :phoenix,
    Endpoint,
    https: false,
    http: [port: @port],
    debug_errors: false,
    server: true
  )

  defmodule UserSocket do
    @behaviour Phoenix.Socket.Transport

    def child_spec(opts) do
      :value = Keyword.fetch!(opts, :custom)
      Supervisor.child_spec({Task, fn -> :ok end}, [])
    end

    def connect(map) do
      %{endpoint: Endpoint, params: params, transport: :websocket} = map
      {:ok, {:params, params}}
    end

    def init({:params, _} = state) do
      {:ok, state}
    end

    def handle_in({"params", opts}, {:params, params} = state) do
      :text = Keyword.fetch!(opts, :opcode)
      {:reply, :ok, {:text, inspect(params)}, state}
    end

    def handle_in({"ping", opts}, state) do
      :text = Keyword.fetch!(opts, :opcode)
      send(self(), :ping)
      {:ok, state}
    end

    def handle_info(:ping, state) do
      {:push, {:text, "pong"}, state}
    end

    def terminate(_reason, {:params, _}) do
      :ok
    end
  end

  defmodule PingSocket do
    @behaviour Phoenix.Socket.Transport

    def child_spec(_opts), do: Supervisor.child_spec({Task, fn -> :ok end}, [id: :ping])
    def connect(_), do: {:ok, %{}}
    def init(state), do: {:ok, state}

    def handle_in({"ping:start", _}, state) do
      {:reply, :ok, :ping, state}
    end
    def handle_in({"ping:start:" <> payload, _}, state) do
      {:reply, :ok, {:ping, payload}, state}
    end
    def handle_info(_, state), do: {:ok, state}

    def handle_control({payload, opts}, state) do
      opcode = Keyword.fetch!(opts, :opcode)
      {:push, {:text, "#{opcode}:#{payload}"}, state}
    end

    def terminate(_reason, _state), do: :ok
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket,
      websocket: [check_origin: ["//example.com"], subprotocols: ["sip"], timeout: 200],
      custom: :value

    socket "/custom/some_path", UserSocket,
      websocket: [path: "nested/path", check_origin: ["//example.com"], timeout: 200],
      custom: :value

    socket "/custom/:socket_var", UserSocket,
      websocket: [path: ":path_var/path", check_origin: ["//example.com"], timeout: 200],
      custom: :value

    socket "/ws/ping", PingSocket,
      websocket: true
  end

  setup_all do
    capture_log(fn -> Endpoint.start_link() end)
    :ok
  end

  test "refuses unallowed origins" do
    capture_log(fn ->
      headers = [{"origin", "https://example.com"}]
      assert {:ok, _} = WebsocketClient.start_link(self(), @path, :noop, headers)

      headers = [{"origin", "http://notallowed.com"}]
      assert {:error, {403, _}} = WebsocketClient.start_link(self(), @path, :noop, headers)
    end)
  end

  test "refuses unallowed Websocket subprotocols" do
    assert capture_log(fn ->
      headers = [{"sec-websocket-protocol", "sip"}]
      assert {:ok, _} = WebsocketClient.start_link(self(), @path, :noop, headers)

      headers = []
      assert {:ok, _} = WebsocketClient.start_link(self(), @path, :noop, headers)

      headers = [{"sec-websocket-protocol", "mqtt"}]
      assert {:error, {403, _}} = WebsocketClient.start_link(self(), @path, :noop, headers)
    end) =~ "Could not check Websocket subprotocols"
  end

  test "returns params with sync request" do
    assert {:ok, client} = WebsocketClient.start_link(self(), "#{@path}?key=value", :noop)
    WebsocketClient.send_message(client, "params")
    assert_receive {:text, ~s(%{"key" => "value"})}
  end

  test "ignores control frames when handle_control/2 is not defined" do
    assert {:ok, client} = WebsocketClient.start_link(self(), @path, :noop)
    WebsocketClient.send_control_frame(client, :ping)
    WebsocketClient.send_message(client, "ping")
    assert_receive {:text, "pong"}
  end

  test "returns pong from async request" do
    assert {:ok, client} = WebsocketClient.start_link(self(), "#{@path}?key=value", :noop)
    WebsocketClient.send_message(client, "ping")
    assert_receive {:text, "pong"}
  end

  test "allows a custom path" do
    path = "ws://127.0.0.1:#{@port}/custom/some_path/nested/path"
    assert {:ok, _} = WebsocketClient.start_link(self(), "#{path}?key=value", :noop)
  end

  test "allows a path with variables" do
    path = "ws://127.0.0.1:#{@port}/custom/123/456/path"
    assert {:ok, client} = WebsocketClient.start_link(self(), "#{path}?key=value", :noop)
    WebsocketClient.send_message(client, "params")
    assert_receive {:text, params}
    assert params =~ ~s("key" => "value")
    assert params =~ ~s("socket_var" => "123")
    assert params =~ ~s(path_var" => "456")
  end

  test "allows using control frames with a payload" do
    path = "ws://127.0.0.1:#{@port}/ws/ping/websocket"
    assert {:ok, client} = WebsocketClient.start_link(self(), path, :noop)
    WebsocketClient.send_control_frame(client, :ping)
    assert_receive({:control, :pong, ""})
    assert_receive({:text, "ping:"})

    WebsocketClient.send_control_frame(client, :ping, "123")
    assert_receive({:control, :pong, "123"})
    assert_receive({:text, "ping:123"})

    WebsocketClient.send_message(client, "ping:start")
    assert_receive({:control, :ping, ""})
    assert_receive({:text, "pong:"})

    WebsocketClient.send_message(client, "ping:start:123")
    assert_receive({:control, :ping, "123"})
    assert_receive({:text, "pong:123"})
  end
end
