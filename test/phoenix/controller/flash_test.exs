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
      conn |> Flash.put_flash(:notice, "elixir") |> redirect(to: "/")
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "flash is persisted when status in redirect" do
    for status <- 300..308 do
      conn = conn_with_session |> put_status(status) |> FlashController.call(:set_flash)
      assert Flash.flash(conn, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = conn_with_session |> put_status(status) |> FlashController.call(:set_flash)
      assert Flash.flash(conn, :notice) == nil
    end
  end

  test "flash/1 returns the map of messages" do
    conn = conn_with_session |> Flash.put_flash(:notice, "hi")
    assert Flash.flash(conn) == %{notice: "hi"}
  end

  test "flash/2 returns the message by key and clears it" do
    conn = conn_with_session |> Flash.put_flash(:notice, "hi")
    assert Flash.flash(conn, :notice) == "hi"
  end

  test "flash/2 returns nil for missing key" do
    conn = conn_with_session
    assert Flash.flash(conn, :notice) == nil
  end

  test "put_flash/3 adds the key/message pair to the flash" do
    conn = conn_with_session
    |> Flash.put_flash(:error, "oh noes!")
    |> Flash.put_flash(:notice, "false alarm!")

    assert Flash.flash(conn, :error) == "oh noes!"
    assert Flash.flash(conn, :notice) == "false alarm!"
  end

  test "clear_flash/1 clears the flash messages" do
    conn = conn_with_session
    |> Flash.put_flash(:error, "oh noes!")
    |> Flash.put_flash(:notice, "false alarm!")

    refute Flash.flash(conn) == %{}
    conn = Flash.clear_flash(conn)
    assert Flash.flash(conn) == %{}
  end
end
