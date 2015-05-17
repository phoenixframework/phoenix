defmodule Phoenix.Controller.PipelineTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller

  defmodule MyController do
    use Phoenix.Controller

    plug :prepend, :before1 when action in [:show, :create, :secret]
    plug :prepend, :before2
    plug :do_halt when action in [:secret]

    def show(conn, _) do
      prepend(conn, :action)
    end

    def create(conn, _) do
      prepend(conn, :action)
    end

    def secret(conn, _) do
      prepend(conn, :secret_action)
    end

    defp do_halt(conn, _), do: halt(conn)

    defp prepend(conn, val) do
      update_in conn.private.stack, &[val|&1]
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "invokes the plug stack" do
    conn = stack_conn()
           |> MyController.call(:show)
    assert conn.private.stack == [:action, :before2, :before1]
  end

  test "invokes the plug stack with guards" do
    conn = stack_conn()
           |> MyController.call(:create)
    assert conn.private.stack == [:action, :before2, :before1]
  end

  test "halts prevent action from running" do
    conn = stack_conn()
           |> MyController.call(:secret)
    assert conn.private.stack == [:before2, :before1]
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
    |> fetch_query_params()
    |> put_private(:stack, [])
  end
end
