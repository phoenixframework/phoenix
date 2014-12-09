defmodule Phoenix.Tranports.LongPollerTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Plug.Conn
  alias Phoenix.Transports.LongPoller
  alias Phoenix.Tranports.LongPollerTest.Router

  @port 4809
  @window_ms 20
  @ensure_window_timeout_ms @window_ms * 3

  def conn_with_session(session \\ %{}) do
    %Conn{private: %{plug_session: session}}
    |> put_private(:phoenix_router, Router)
    |> put_private(:phoenix_endpoint, __MODULE__)
  end

  def config(:transports) do
    [longpoller_window_ms: @window_ms]
  end

  defmodule Router do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"
  end

  test "start_session starts the LongPoller.Server and stores pid in session" do
    conn = conn_with_session
    assert LongPoller.longpoll_pid(conn) == :nopid
    {conn = %Conn{}, server_pid} = LongPoller.start_session(conn)

    assert Process.alive?(server_pid)
    {:ok, decoded_pid} = LongPoller.longpoll_pid(conn)
    assert server_pid == decoded_pid
  end

  test "longpoll_pid returns {:error, :terminated} if serialized pid is dead" do
    {conn = %Conn{}, server_pid} = LongPoller.start_session(conn_with_session)
    assert Process.alive?(server_pid)
    :timer.sleep @ensure_window_timeout_ms
    refute Process.alive?(server_pid)
    assert {:error, :terminated} = LongPoller.longpoll_pid(conn)
  end

  test "resume_session returns {:ok, conn, pid} if valid session" do
    {conn = %Conn{}, server_pid} = LongPoller.start_session(conn_with_session)
    assert {:ok, %Conn{}, ^server_pid} = LongPoller.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if dead session" do
    {conn = %Conn{}, _server_pid} = LongPoller.start_session(conn_with_session)
    :timer.sleep @ensure_window_timeout_ms
    assert {:error, %Conn{}, :terminated} = LongPoller.resume_session(conn)
  end

  test "resume_session returns {:error, conn, :terminated} if missing session" do
    conn = conn_with_session
    assert {:error, %Conn{}, :terminated} = LongPoller.resume_session(conn)
  end
end
