defmodule Phoenix.Controller.PipelineTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller

  defmodule MyController do
    use Phoenix.Controller

    plug :prepend, :before1 when action in [:show, :create, :secret]
    plug :prepend, :before2
    plug :do_halt when action in [:secret]
    plug :send_early when action in [:already_sent_no_match]

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

    def already_sent_no_match(_conn, %{"no" => "match"}) do
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

    defp send_early(conn, _), do: send_resp(conn, :ok, "")
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

  test "transforms top-level action function clause errors into 400 responses" do
    conn = MyController.call(stack_conn(), :no_match)

    assert conn.status == 400
  end

  test "does not send 400 if response already sent when action FunctionClauseError's" do
    conn = MyController.call(stack_conn(), :already_sent_no_match)

    assert conn.state == :sent
    assert conn.status == nil
  end

  test "does not transform function clause errors lower in action stack" do
    assert_raise FunctionClauseError, fn ->
      MyController.call(stack_conn(), :non_top_level_function_clause_error)
    end
  end


  defp stack_conn() do
    conn(:get, "/")
    |> fetch_query_params()
    |> put_private(:stack, [])
  end
end
