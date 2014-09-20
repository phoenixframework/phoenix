defmodule Phoenix.Controller.StackTest do
  use ExUnit.Case, async: true
  use ConnHelper

  defmodule MyController do
    use Phoenix.Controller

    before_action :prepend, :before1 when action in [:show, :create]
    before_action :prepend, :before2
    after_action :prepend, :after1
    after_action :prepend, :after2
    after_action :done when not action in [:create]

    defp prepend(conn, val) do
      update_in conn.private.stack, &[val|&1]
    end

    defp done(conn, _) do
      prepend(conn, :done)
    end

    def show(conn, _) do
      prepend(conn, :action)
    end

    def create(conn, _) do
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
           [:done, :after2, :after1, :action, :before2, :before1]
  end

  test "invokes the plug stack with guards" do
    conn = conn(:get, "/")
           |> fetch_params()
           |> put_private(:stack, [])
           |> MyController.call(:create)
    assert conn.private.stack ==
           [:after2, :after1, :action, :before2, :before1]
  end
end
