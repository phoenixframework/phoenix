defmodule Phoenix.Controller.FlashTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Controller.Flash

  @session Plug.Session.init(
    store: :cookie,
    key: "_app",
    encryption_salt: "yadayada",
    signing_salt: "yadayada"
  )

  def conn_with_session() do
    conn(:get, "/")
    |> Map.put(:secret_key_base, String.duplicate("abcdefgh", 8))
    |> Plug.Session.call(@session)
    |> fetch_session()
  end

  defmodule FlashController do
    use Phoenix.Controller

    plug :action

    def set_flash(conn, _params) do
      conn |> Flash.put(:notice, "elixir") |> redirect(to: "/")
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "flash is persisted when status in redirect" do
    for status <- 300..308 do
      conn = conn_with_session |> put_status(status) |> FlashController.call(:set_flash)
      assert Flash.get(conn, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = conn_with_session |> put_status(status) |> FlashController.call(:set_flash)
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

  test "pop_all/2 pops all messages from the flash" do
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
