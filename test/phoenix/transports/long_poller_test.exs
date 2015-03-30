defmodule Phoenix.Tranports.LongPollerTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:lp_app, __MODULE__.Endpoint, [
    server: false,
    transports: [longpoller_window_ms: 10_000, longpoller_pubsub_timeout_ms: 100],
    pubsub: [name: :phx_lp_pub, adapter: Phoenix.PubSub.PG2]
  ])

  alias Plug.Conn
  alias Phoenix.Transports.LongPoller
  alias Phoenix.Tranports.LongPollerTest.Router

  def conn_with_sess(session \\ %{}) do
    %Conn{private: %{plug_session: session}}
    |> put_private(:phoenix_router, Router)
    |> put_private(:phoenix_endpoint, __MODULE__.Endpoint)
    |> with_session
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :lp_app
  end

  defmodule Router do
    use Phoenix.Router

    socket "/ws" do
    end
  end

  setup_all do
    capture_log fn -> Endpoint.start_link end
    :ok
  end


  test "start_session starts the LongPoller.Server and stores pid in session" do
    conn = conn_with_sess
    assert LongPoller.verify_longpoll_topic(conn) == :notopic
    {conn = %Conn{}, priv_topic, sig, server_pid} = LongPoller.start_session(conn)
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}

    assert Process.alive?(server_pid)
    {:ok, verified_topic} = LongPoller.verify_longpoll_topic(conn)
    assert priv_topic == verified_topic
  end

  test "verify_longpoll_topic returns {:error, :terminated} if serialized pid is dead" do
    {conn = %Conn{}, priv_topic, sig, server_pid} = LongPoller.start_session(conn_with_sess)
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}
    assert {:ok, ^priv_topic} = LongPoller.verify_longpoll_topic(conn)
    assert Process.alive?(server_pid)
    :ok = GenServer.call(server_pid, :stop)
    assert {:error, :terminated} = LongPoller.verify_longpoll_topic(conn)
    refute Process.alive?(server_pid)
  end

  test "resume_session returns {:ok, conn, pid} if valid session" do
    {conn = %Conn{}, priv_topic, sig, _server_pid} = LongPoller.start_session(conn_with_sess)
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}
    assert {:ok, %Conn{}, ^priv_topic} = LongPoller.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if dead session" do
    {conn = %Conn{}, _priv_topic, _sig, server_pid} = LongPoller.start_session(conn_with_sess)
    :ok = GenServer.call(server_pid, :stop)
    assert {:error, %Conn{}, :terminated} = LongPoller.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if missing session" do
    conn = conn_with_sess
    assert {:error, %Conn{}, :terminated} = LongPoller.resume_session(conn)
  end
end
