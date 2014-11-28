defmodule Phoenix.Tranports.LongPollerTest do
  use ExUnit.Case, async: true
  use ConnHelper
  import ExUnit.CaptureIO

  alias Plug.Conn
  alias Phoenix.Transports.LongPoller
  alias Phoenix.Tranports.LongPollerTest.Router

  def conn_with_session(session \\ %{}) do
    %Conn{private: %{plug_session: session}}
    |> put_private(:phoenix_router, Router)
  end

  @port 4809
  @window_ms 20
  @ensure_window_timeout_ms @window_ms * 3

  Application.put_env(:phoenix, Router, [
    https: false,
    http: [port: @port],
    secret_key_base: "7pe/JuPlX/rvpyk80h5r9eShTBtTLIY4WcDIX/r60Fz+8pnQDc1usobc9D7KvD9/l6DNZBXo5Uc8HXSpsuwCcA==",
    session: [store: :cookie, key: "_unit_test"],
    transports: [longpoller: [window_ms: @window_ms]]
  ])

  defmodule Router do
    use Phoenix.Router
    use Phoenix.Router.Socket, mount: "/ws"
  end

  setup_all do
    capture_io fn -> Router.start end
    on_exit &Router.stop/0
    :ok
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
