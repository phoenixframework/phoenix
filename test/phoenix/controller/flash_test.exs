defmodule Phoenix.Controller.FlashTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller

  setup do
    Logger.disable(self())
    :ok
  end

  test "flash is persisted when status is in redirect" do
    for status <- 300..308 do
      conn = conn(:get, "/") |> with_session |> fetch_flash() |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert get_flash(conn, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
      assert get_flash(conn, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = conn(:get, "/") |> with_session |> fetch_flash() |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert get_flash(conn, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
      assert get_flash(conn, :notice) == nil
    end
  end

  test "flash does not write to session in case it is empty" do
    conn = conn(:get, "/") |> with_session |> fetch_flash() |> send_resp(200, "ok")
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "get_flash/1 raises ArgumentError when flash not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> with_session |> get_flash()
    end
  end

  test "get_flash/1 returns the map of messages" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert get_flash(conn) == %{notice: "hi"}
  end

  test "get_flash/2 returns the message by key" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert get_flash(conn, :notice) == "hi"
  end

  test "get_flash/2 returns nil for missing key" do
    conn = conn(:get, "/") |> with_session |> fetch_flash([])
    assert get_flash(conn, :notice) == nil
  end

  test "put_flash/3 raises ArgumentError when flash not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> with_session |> put_flash(:error, "boom!")
    end
  end

  test "put_flash/3 adds the key/message pair to the flash" do
    conn =
      conn(:get, "/")
      |> with_session
      |> fetch_flash([])
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    assert get_flash(conn, :error) == "oh noes!"
    assert get_flash(conn, :notice) == "false alarm!"
  end

  test "clear_flash/1 clears the flash messages" do
    conn =
      conn(:get, "/")
      |> with_session
      |> fetch_flash([])
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    refute get_flash(conn) == %{}
    conn = clear_flash(conn)
    assert get_flash(conn) == %{}
  end

  test "fetch_flash/2 raises ArugmentError when session not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> fetch_flash([])
    end
  end
end
