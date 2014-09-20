defmodule Phoenix.Controller.StackTest do
  use ExUnit.Case, async: true
  use ConnHelper

  defmodule MyController do
    use Phoenix.Controller

    before_action :prepend, :before1
    before_action :prepend, :before2
    after_action :prepend, :after1
    after_action :prepend, :after2

    def prepend(conn, val) do
      update_in conn.private.stack, &[val|&1]
    end

    def show(conn, _) do
      prepend(conn, :action)
    end
  end

  setup do
    Logger.disable(self())
  end

  test "invokes the plug stack" do
    conn = conn(:get, "/")
           |> fetch_params()
           |> put_private(:stack, [])
           |> MyController.call(:show)
    assert conn.private.stack ==
           [:after2, :after1, :action, :before2, :before1]
  end
end
