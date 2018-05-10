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
      {:reply, :ok, {:text, Phoenix.json_library().encode!(params)}, state}
    end

    def handle_in({"ping", opts}, state) do
      :text = Keyword.fetch!(opts, :opcode)
      send(self(), :ping)
      {:ok, state}
    end

    def handle_info(:ping, state) do
      {:push, {:text, Phoenix.json_library().encode!("pong")}, state}
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

  def poll(method, params, body \\ nil, headers \\ %{}) do
    headers = Map.merge(%{"content-type" => "application/json"}, headers)
    url = "http://127.0.0.1:#{@port}/ws/longpoll?" <> URI.encode_query(params)
    {:ok, resp} = HTTPClient.request(method, url, headers, body)
    update_in(resp.body, &Phoenix.json_library().decode!(&1))
  end

  test "refuses unallowed origins" do
    capture_log(fn ->
      resp = poll(:get, %{}, nil, %{"origin" => "https://example.com"})
      assert resp.body["status"] == 410

      resp = poll(:get, %{}, nil, %{"origin" => "http://notallowed.com"})
      assert resp.body["status"] == 403
    end)
  end

  test "returns params with sync request" do
    resp = poll(:get, %{"hello" => "world"}, nil)
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200
    secret = Map.take(resp.body, ["token"])

    resp = poll(:post, secret, "params")
    assert resp.body["status"] == 200

    resp = poll(:get, secret, nil)
    assert resp.body["messages"] == [%{"hello" => "world"}]
  end

  test "returns pong from async request" do
    resp = poll(:get, %{"hello" => "world"}, nil)
    assert resp.body["token"]
    assert resp.body["status"] == 410
    assert resp.status == 200
    secret = Map.take(resp.body, ["token"])

    resp = poll(:post, secret, "ping")
    assert resp.body["status"] == 200

    resp = poll(:get, secret, nil)
    assert resp.body["messages"] == ["pong"]
  end
end
