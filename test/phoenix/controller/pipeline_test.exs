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

    def no_fallback(_conn, _) do
      :not_a_conn
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

  defmodule FallbackFunctionController do
    use Phoenix.Controller

    action_fallback :function_plug

    plug :put_assign

    def fallback(_conn, _), do: :not_a_conn

    def bad_fallback(_conn, _), do: :bad_fallback

    defp function_plug(%Plug.Conn{} = conn, :not_a_conn) do
      Plug.Conn.send_resp(conn, 200, "function fallback")
    end
    defp function_plug(%Plug.Conn{}, :bad_fallback), do: :bad_function_fallback

    defp put_assign(conn, _), do: assign(conn, :value_before_action, :a_value)
  end

  defmodule ActionController do
    use Phoenix.Controller

    action_fallback Phoenix.Controller.PipelineTest

    plug :put_assign

    def action(conn, _) do
      apply(__MODULE__, conn.private.phoenix_action, [conn, conn.body_params,
                                                      conn.query_params])
    end

    def show(conn, _, _), do: text(conn, "show")

    def no_match(_conn, _, %{"no" => "match"}) do
      raise "Shouldn't have matched"
    end

    def fallback(_conn, _, _) do
      :not_a_conn
    end

    def bad_fallback(_conn, _, _) do
      :bad_fallback
    end

    defp put_assign(conn, _), do: assign(conn, :value_before_action, :a_value)
  end
  def init(opts), do: opts
  def call(conn, :not_a_conn), do: Plug.Conn.send_resp(conn, 200, "fallback")
  def call(_conn, :bad_fallback), do: :bad_fallback

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

  test "wraps function clause errors lower in action stack in Plug.Conn.WrapperError" do
    assert_raise Plug.Conn.WrapperError, fn ->
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

  describe "action_fallback" do
    test "module fallback delegates to plug for bad return values when not configured" do
      assert_raise RuntimeError, ~r/expected action\/2 to return a Plug.Conn/, fn ->
        MyController.call(stack_conn(), :no_fallback)
      end
    end

    test "module fallback invokes module plug when configured" do
      conn = ActionController.call(stack_conn(), :fallback)
      assert conn.status == 200
      assert conn.assigns.value_before_action == :a_value
      assert conn.resp_body == "fallback"
    end

    test "module fallback with bad return delegates to plug" do
      assert_raise RuntimeError, ~r/expected action\/2 to return a Plug.Conn/, fn ->
        ActionController.call(stack_conn(), :bad_fallback)
      end
    end

    test "function fallback invokes module plug when configured" do
      conn = FallbackFunctionController.call(stack_conn(), :fallback)
      assert conn.status == 200
      assert conn.assigns.value_before_action == :a_value
      assert conn.resp_body == "function fallback"
    end

    test "function fallback with bad return delegates to plug" do
      assert_raise RuntimeError, ~r/expected action\/2 to return a Plug.Conn/, fn ->
        FallbackFunctionController.call(stack_conn(), :bad_fallback)
      end
    end

    test "raises when calling from import instead of use", config do
      assert_raise RuntimeError, ~r/can only be called when using Phoenix.Controller/, fn ->
        defmodule config.test do
          import Phoenix.Controller
          action_fallback Boom
        end
      end
    end

    test "raises when calling more than once", config do
      assert_raise RuntimeError, ~r/can only be called a single time/, fn ->
        defmodule config.test do
          use Phoenix.Controller
          action_fallback Ok
          action_fallback Boom
        end
      end
    end
  end

  defp stack_conn() do
    conn(:get, "/")
    |> fetch_query_params()
    |> put_private(:stack, [])
  end
end
