defmodule Phoenix.Controller.FlashTest do
  use ExUnit.Case
  use ConnHelper
  alias Phoenix.Controller.Flash
  alias Phoenix.Controller.FlashTest.Router

  def conn_with_session(session \\ %{}) do
    %Conn{private: %{plug_session: session}}
  end

  setup_all do
    Mix.Config.persist(phoenix: [
      {Router,
        cookies: true,
        session_key: "_app",
        session_secret: "111111111111111111111111111111111111111111111111111111111111111111111111111"
      }
    ])

    defmodule FlashController do
      use Phoenix.Controller

      def index(conn, _params) do
        text conn, "hello"
      end

      def set_flash(conn, %{"notice" => notice, "status" => status}) do
        {status, _} = Integer.parse(status)
        conn |> Flash.put(:notice, notice) |> redirect(status, "/")
      end
    end

    defmodule Router do
      use Phoenix.Router
      get "/", FlashController, :index
      get "/set_flash/:notice/:status", FlashController, :set_flash
    end

    :ok
  end

  test "flash is persisted when status in redirect" do
    for status <- 300..308 do
      conn = simulate_request(Router, :get, "/set_flash/elixir/#{status}")
      assert Flash.get(conn, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = simulate_request(Router, :get, "/set_flash/elixir/#{status}")
      assert Flash.get(conn, :notice) == nil
    end
  end

  test "get/1 returns the map of messages" do
    conn = conn_with_session |> Flash.put(:notice, "hi")
    assert Flash.get(conn) == %{notice: ["hi"]}
  end

  test "get/2 returns the message by key" do
    conn = conn_with_session |> Flash.put(:notice, "hi")
    assert Flash.get(conn, :notice) == "hi"
  end

  test "get/2 returns the only the last message put" do
    conn = conn_with_session
    |> Flash.put(:notice, "hi")
    |> Flash.put(:notice, "bye")
    assert Flash.get(conn, :notice) == "bye"
  end

  test "get/2 returns nil for missing key" do
    conn = conn_with_session
    assert Flash.get(conn, :notice) == nil
  end

  test "get_all/2 returns a list of messages by key" do
    conn = conn_with_session
    |> Flash.put(:notices, "hello")
    |> Flash.put(:notices, "world")

    assert Flash.get_all(conn, :notices) == ["hello", "world"]
  end

  test "get_all/2 returns [] for missing key" do
    conn = conn_with_session
    assert Flash.get_all(conn, :notices) == []
  end

  test "put/3 adds the key/message pair to the flash" do
    conn = conn_with_session
    |> Flash.put(:error, "oh noes!")
    |> Flash.put(:notice, "false alarm!")

    assert Flash.get(conn, :error) == "oh noes!"
    assert Flash.get(conn, :notice) == "false alarm!"
  end

  test "clear/1 clears the flash messages" do
    conn = conn_with_session
    |> Flash.put(:error, "oh noes!")
    |> Flash.put(:notice, "false alarm!")

    refute Flash.get(conn) == %{}
    conn = Flash.clear(conn)
    assert Flash.get(conn) == %{}
  end

  test "pop_all/3 pops all messages from the flash" do
    conn = conn_with_session
    assert match?{[], _conn}, Flash.pop_all(conn, :notices)

    conn = conn
    |> Flash.put(:notices, "oh noes!")
    |> Flash.put(:notices, "false alarm!")

    {messages, conn} = Flash.pop_all(conn, :notices)
    assert messages == ["oh noes!", "false alarm!"]
    assert Flash.get(conn) == %{}
  end
end

