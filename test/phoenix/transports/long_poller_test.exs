defmodule Phoenix.Tranports.LongPollTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:lp_app, __MODULE__.Endpoint, [
    server: false,
    pubsub: [name: :phx_lp_pub, adapter: Phoenix.PubSub.PG2]
  ])

  alias Plug.Conn
  alias Phoenix.Transports.LongPoll
  alias Phoenix.Tranports.LongPollTest.Router

  def conn_with_sess(session \\ %{}) do
    {_, longpoll_conf} = __MODULE__.UserSocket.__transport__(:longpoll)
    %Conn{private: %{plug_session: session}}
    |> put_private(:phoenix_router, Router)
    |> put_private(:phoenix_endpoint, __MODULE__.Endpoint)
    |> put_private(:phoenix_socket_handler, __MODULE__.UserSocket)
    |> put_private(:phoenix_transport_conf, longpoll_conf)
    |> with_session()
  end

  defmodule UserSocket do
    use Phoenix.Socket

    transport :longpoll, Phoenix.Transports.LongPoll,
      window_ms: 10_000,
      pubsub_timeout_ms: 100,
      crypto: [iterations: 1000, length: 32, digest: :sha256, cache: Plug.Keys]

    def connect(_params, socket), do: {:ok, socket}

    def id(_), do: "user_sockets:123"
  end


  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :lp_app

    socket "/ws", UserSocket
  end

  defmodule Router do
    use Phoenix.Router
  end

  defp new_socket() do
    {:ok, socket} = Phoenix.Channel.Transport.socket_connect(Endpoint, LongPoll, UserSocket, %{})
    socket
  end

  setup_all do
    capture_log fn -> Endpoint.start_link() end
    :ok
  end

  test "start_session starts the LongPoll.Server and stores pid in session" do
    conn = conn_with_sess()
    assert LongPoll.verify_longpoll_topic(conn) == :notopic
    {conn = %Conn{}, priv_topic, sig, server_pid} = LongPoll.start_session(conn, new_socket())
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}

    assert Process.alive?(server_pid)
    {:ok, verified_topic} = LongPoll.verify_longpoll_topic(conn)
    assert priv_topic == verified_topic
  end

  test "verify_longpoll_topic returns {:error, :terminated} if serialized pid is dead" do
    {conn = %Conn{}, priv_topic, sig, server_pid} = LongPoll.start_session(conn_with_sess(), new_socket())
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}
    assert {:ok, ^priv_topic} = LongPoll.verify_longpoll_topic(conn)
    assert Process.alive?(server_pid)
    :ok = GenServer.call(server_pid, :stop)
    assert {:error, :terminated} = LongPoll.verify_longpoll_topic(conn)
    refute Process.alive?(server_pid)
  end

  test "resume_session returns {:ok, conn, pid} if valid session" do
    {conn = %Conn{}, priv_topic, sig, _server_pid} = LongPoll.start_session(conn_with_sess(), new_socket())
    conn = put_in conn.params, %{"token" => priv_topic, "sig" => sig}
    assert {:ok, %Conn{}, ^priv_topic} = LongPoll.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if dead session" do
    {conn = %Conn{}, _priv_topic, _sig, server_pid} = LongPoll.start_session(conn_with_sess(), new_socket())
    :ok = GenServer.call(server_pid, :stop)
    assert {:error, %Conn{}, :terminated} = LongPoll.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if missing session" do
    conn = conn_with_sess()
    assert {:error, %Conn{}, :terminated} = LongPoll.resume_session(conn)
  end
end
