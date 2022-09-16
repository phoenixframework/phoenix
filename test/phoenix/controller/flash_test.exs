defmodule Phoenix.Controller.FlashTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller

  alias Phoenix.Flash

  setup do
    Logger.disable(self())
    :ok
  end

  @session Plug.Session.init(
    store: :cookie,
    key: "_app",
    encryption_salt: "yadayada",
    signing_salt: "yadayada"
  )

  def with_session(conn) do
    conn
    |> Map.put(:secret_key_base, String.duplicate("abcdefgh", 8))
    |> Plug.Session.call(@session)
    |> Plug.Conn.fetch_session()
  end

  test "does not fetch flash twice" do
    expected_flash = %{"foo" => "bar"}
    conn =
      conn(:get, "/")
      |> with_session()
      |> put_session("phoenix_flash", expected_flash)
      |> fetch_flash()
      |> put_session("phoenix_flash", %{"foo" => "baz"})
      |> fetch_flash()

    assert conn.assigns.flash == expected_flash
    assert conn.assigns.flash == expected_flash
  end

  test "flash is persisted when status is a redirect" do
    for status <- 300..308 do
      conn = conn(:get, "/") |> with_session |> fetch_flash()
                             |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert Flash.get(conn.assigns.flash, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
      assert Flash.get(conn.assigns.flash, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = conn(:get, "/") |> with_session |> fetch_flash()
                             |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert Flash.get(conn.assigns.flash, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
      assert Flash.get(conn.assigns.flash, :notice) == nil
    end
  end

  test "flash does not write to session when it is empty and no session exists" do
    conn =
      conn(:get, "/")
      |> with_session()
      |> fetch_flash()
      |> clear_flash()
      |> send_resp(302, "ok")

    assert get_resp_header(conn, "set-cookie") == []
  end

  test "flash writes to session when it is empty and a previous session exists" do
    persisted_flash_conn =
      conn(:get, "/")
      |> with_session()
      |> fetch_flash()
      |> put_flash(:info, "existing")
      |> send_resp(302, "ok")

    conn =
      conn(:get, "/")
      |> Plug.Test.recycle_cookies(persisted_flash_conn)
      |> with_session()
      |> fetch_flash()
      |> clear_flash()
      |> send_resp(200, "ok")

    assert ["_app=" <> _] = get_resp_header(conn, "set-cookie")
  end

  test "flash assigns contains the map of messages" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert conn.assigns.flash == %{"notice" => "hi"}
  end

  test "Flash.get/2 returns the message by key" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert Flash.get(conn.assigns.flash, :notice) == "hi"
    assert Flash.get(conn.assigns.flash, "notice") == "hi"
  end

  test "Flash.get/2 returns nil for missing key" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([])
    assert Flash.get(conn.assigns.flash, :notice) == nil
    assert Flash.get(conn.assigns.flash, "notice") == nil
  end

  test "put_flash/3 raises ArgumentError when flash not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> with_session |> put_flash(:error, "boom!")
    end
  end

  test "put_flash/3 adds the key/message pair to the flash and updates assigns" do
    conn =
      conn(:get, "/")
      |> with_session
      |> fetch_flash([])

    assert conn.assigns.flash == %{}

    conn =
      conn
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    assert conn.assigns.flash == %{"error" => "oh noes!", "notice" => "false alarm!"}
    assert Flash.get(conn.assigns.flash, :error) == "oh noes!"
    assert Flash.get(conn.assigns.flash, "error") == "oh noes!"
    assert Flash.get(conn.assigns.flash, :notice) == "false alarm!"
    assert Flash.get(conn.assigns.flash, "notice") == "false alarm!"
  end

  test "clear_flash/1 clears the flash messages" do
    conn =
      conn(:get, "/")
      |> with_session
      |> fetch_flash([])
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    refute conn.assigns.flash == %{}
    conn = clear_flash(conn)
    assert conn.assigns.flash == %{}
  end

  test "merge_flash/2 adds kv-pairs to the flash" do
    conn =
      conn(:get, "/")
      |> with_session
      |> fetch_flash([])
      |> merge_flash(error: "oh noes!", notice: "false alarm!")

    assert Flash.get(conn.assigns.flash, :error) == "oh noes!"
    assert Flash.get(conn.assigns.flash, "error") == "oh noes!"
    assert Flash.get(conn.assigns.flash, :notice) == "false alarm!"
    assert Flash.get(conn.assigns.flash, "notice") == "false alarm!"
  end

  test "fetch_flash/2 raises ArgumentError when session not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> fetch_flash([])
    end
  end

  describe "Flash" do
    test "get/2" do
      assert Flash.get(%{}, :info) == nil
      assert Flash.get(%{"info" => "hi"}, :info) == "hi"
      assert Flash.get(%{"info" => "hi", "error" => "ohno"}, :error) == "ohno"
    end

    test "invalid access" do
      assert_raise ArgumentError, ~r/expected a map of flash data, but got a %Plug.Conn{}/, fn ->
        Flash.get(%Plug.Conn{}, :info)
      end
    end
  end
end
