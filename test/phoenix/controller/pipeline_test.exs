defmodule Phoenix.Controller.PipelineTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller
  import Phoenix.Controller.Pipeline, only: [invoke_afters: 2]

  defmodule MyController do
    use Phoenix.Controller

    plug :prepend, :before1 when action in [:show, :create, :secret]
    plug :prepend, :before2
    plug :do_halt when action in [:secret]

    plug :reg_after, {__MODULE__, :prepend, :after1}
    plug :reg_after, {__MODULE__, :prepend, :after2}
    plug :reg_after, {__MODULE__, :prepend, :done} when not action in [:create]

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

    defp reg_after(conn, {mod, func, opts}) do
      register_after_action(conn, fn conn -> apply(mod, func, [conn, opts]) end)
    end

    def prepend(conn, val) do
      update_in conn.private.stack, &[val|&1]
    end

    def done(conn, _) do
      prepend(conn, :done)
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "invokes the plug stack with registered action hooks" do
    conn = stack_conn()
           |> MyController.call(:show)
    assert conn.private.stack ==
           [:done, :after2, :after1, :action, :before2, :before1]
  end

  test "halts prevent action and register_after_action's from running" do
    conn = stack_conn()
           |> MyController.call(:secret)
    assert conn.private.stack ==
           [:before2, :before1]
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

  test "register_after_action/2 accumulates callbacks for invoke_afters/1" do
    conn = assign(%Plug.Conn{}, :invoked_afters, [])
    conn = register_after_action(conn, fn conn ->
      assign(conn, :invoked_afters, conn.assigns[:invoked_afters] ++ [:after1])
    end)
    conn = register_after_action(conn, fn conn ->
      assign(conn, :invoked_afters, conn.assigns[:invoked_afters] ++ [:after2])
    end)
    conn = invoke_afters(conn, [])
    assert conn.assigns[:invoked_afters] == [:after1, :after2]
  end

  defp stack_conn() do
    conn(:get, "/")
    |> fetch_query_params()
    |> put_private(:stack, [])
  end
end
