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

    def no_match(_conn, %{"no" => "match"}) do
      raise "Shouldn't have matched"
    end

    def non_top_level_function_clause_error(conn, params) do
      send_resp(conn, :ok, trigger_func_clause_error(params))
    end

    defp trigger_func_clause_error(%{"no" => "match"}), do: :nomatch

    defp do_halt(conn, _), do: halt(conn)

    defp prepend(conn, val) do
      update_in conn.private.stack, &[val|&1]
    end
  end

  defmodule ActionController do
    use Phoenix.Controller

    def action(conn, _) do
      apply(__MODULE__, conn.private.phoenix_action, [conn, conn.body_params,
                                                      conn.query_params])
    end

    def show(conn, _, _), do: text(conn, "show")

    def no_match(_conn, _, %{"no" => "match"}) do
      raise "Shouldn't have matched"
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

  test "transforms top-level function clause errors into Phoenix.ActionClauseError" do
    assert_raise Phoenix.ActionClauseError, fn ->
      MyController.call(stack_conn(), :no_match)
    end
  end

  test "does not transform function clause errors lower in action stack" do
    assert_raise FunctionClauseError, fn ->
      MyController.call(stack_conn(), :non_top_level_function_clause_error)
    end
  end

  test "action/2 is overridable and still wraps function clause transforms" do
    conn = ActionController.call(stack_conn(), :show)
    assert conn.status == 200
    assert conn.resp_body == "show"

    assert_raise Phoenix.ActionClauseError, fn ->
      ActionController.call(stack_conn(), :no_match)
    end
  end

  defp stack_conn() do
    conn(:get, "/")
    |> fetch_query_params()
    |> put_private(:stack, [])
  end
end
