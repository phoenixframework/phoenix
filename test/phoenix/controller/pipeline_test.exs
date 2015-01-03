defmodule Phoenix.Controller.PipelineTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller

  defmodule MyController do
    use Phoenix.Controller

    plug :prepend, :before1 when action in [:show, :create]
    plug :prepend, :before2
    plug :action
    plug :prepend, :after1
    plug :prepend, :after2
    plug :done when not action in [:create]

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
    :ok
  end

  test "invokes the plug stack" do
    conn = stack_conn()
           |> MyController.call(:show)
    assert conn.private.stack ==
           [:done, :after2, :after1, :action, :before2, :before1]
  end

  test "invokes the plug stack with guards" do
    conn = stack_conn()
           |> MyController.call(:create)
    assert conn.private.stack ==
           [:after2, :after1, :action, :before2, :before1]
  end

  test "does not override previous views/layouts" do
    conn = stack_conn()
           |> put_view(Hello)
           |> put_layout(false)
           |> MyController.call(:create)
    assert view_module(conn) == Hello
    assert layout(conn) == false
  end

  defp stack_conn() do
    conn(:get, "/")
    |> fetch_params()
    |> put_private(:stack, [])
  end
end
