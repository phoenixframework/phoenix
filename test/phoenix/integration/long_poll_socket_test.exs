Code.require_file("../../support/http_client.exs", __DIR__)

defmodule Phoenix.Integration.LongPollSocketTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Phoenix.Integration.HTTPClient
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5908
  @pool_size 1

  Application.put_env(
    :phoenix,
    Endpoint,
    https: false,
    http: [port: @port],
    debug_errors: false,
    secret_key_base: String.duplicate("abcdefgh", 8),
    server: true,
    pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__, pool_size: @pool_size]
  )

  defmodule UserSocket do
    @behaviour Phoenix.Socket.Transport

    def child_spec(opts) do
      :value = Keyword.fetch!(opts, :custom)
      Supervisor.Spec.worker(Task, [fn -> :ok end], restart: :transient)
    end

    def connect(map) do
      %{endpoint: Endpoint, params: params, transport: :longpoll} = map
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

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket,
      longpoll: [window_ms: 200, pubsub_timeout_ms: 200, check_origin: ["//example.com"]],
      custom: :value

    socket "/custom/:socket_var", UserSocket,
      longpoll: [path: ":path_var/path", check_origin: ["//example.com"], timeout: 200],
      custom: :value
  end

  setup_all do
    capture_log(fn -> Endpoint.start_link() end)
    :ok
  end

  setup do
    for {_, pid, _, _} <- Supervisor.which_children(Phoenix.Transports.LongPoll.Supervisor) do
      Supervisor.terminate_child(Phoenix.Transports.LongPoll.Supervisor, pid)
    end

    :ok
  end

  def poll(method, path, params, body \\ nil, headers \\ %{}) do
    headers = Map.merge(%{"content-type" => "application/json"}, headers)
    url = "http://127.0.0.1:#{@port}/#{path}?" <> URI.encode_query(params)
    {:ok, resp} = HTTPClient.request(method, url, headers, body)
    update_in(resp.body, &Phoenix.json_library().decode!(&1))
  end

  test "refuses unallowed origins" do
    capture_log(fn ->
      resp = poll(:get, "ws/longpoll", %{}, nil, %{"origin" => "https://example.com"})
      assert resp.body["status"] == 410

      resp = poll(:get, "ws/longpoll", %{}, nil, %{"origin" => "http://notallowed.com"})
      assert resp.body["status"] == 403
    end)
  end

  test "returns params with sync request" do
    resp = poll(:get, "ws/longpoll", %{"hello" => "world"}, nil)
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200
    secret = Map.take(resp.body, ["token"])

    resp = poll(:post, "ws/longpoll", secret, "params")
    assert resp.body["status"] == 200

    resp = poll(:get, "ws/longpoll", secret, nil)
    assert resp.body["messages"] == [~s(%{"hello" => "world"})]
  end

  @tag :cowboy2
  test "allows a path with variables" do
    path = "custom/123/456/path"
    resp = poll(:get, path, %{"key" => "value"}, nil)
    secret = Map.take(resp.body, ["token"])

    resp = poll(:post, path, secret, "params")
    assert resp.body["status"] == 200

    resp = poll(:get, path, secret, nil)
    [params] = resp.body["messages"]
    assert params =~ ~s("key" => "value")
    assert params =~ ~s("socket_var" => "123")
    assert params =~ ~s(path_var" => "456")
  end

  test "returns pong from async request" do
    resp = poll(:get, "ws/longpoll", %{"hello" => "world"}, nil)
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200
    secret = Map.take(resp.body, ["token"])

    resp = poll(:post, "ws/longpoll", secret, "ping")
    assert resp.body["status"] == 200

    resp = poll(:get, "ws/longpoll", secret, nil)
    assert resp.body["messages"] == ["pong"]
  end
end
