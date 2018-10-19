defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  def init(opts), do: opts

  defmodule AdminRouter do
    def init(opts), do: opts
    def call(conn, _), do: Plug.Conn.assign(conn, :fwd_conn, conn)
  end

  test "builds a route based on verb, path, plug, plug options and helper" do
    route = build(1, :match, :get, "/foo/:bar", nil, Hello, :world, "hello_world", [:foo, :bar], %{foo: "bar"}, %{bar: "baz"})
    assert route.kind == :match
    assert route.verb == :get
    assert route.path == "/foo/:bar"
    assert route.host == nil
    assert route.line == 1

    assert route.plug == Hello
    assert route.opts == :world
    assert route.helper == "hello_world"
    assert route.pipe_through == [:foo, :bar]
    assert route.private == %{foo: "bar"}
    assert route.assigns == %{bar: "baz"}
  end

  test "builds expressions based on the route" do
    exprs = build(1, :match, :get, "/foo/:bar", nil, Hello, :world, "hello_world", [], %{}, %{}) |> exprs
    assert exprs.verb_match == "GET"
    assert exprs.path == ["foo", {:bar, [], nil}]
    assert exprs.binding == [{"bar", {:bar, [], nil}}]
    assert Macro.to_string(exprs.host) == "_"

    exprs = build(1, :match, :get, "/", "foo.", Hello, :world, "hello_world", [:foo, :bar], %{foo: "bar"}, %{bar: "baz"}) |> exprs
    assert Macro.to_string(exprs.host) == "\"foo.\" <> _"

    exprs = build(1, :match, :get, "/", "foo.com", Hello, :world, "hello_world", [], %{foo: "bar"}, %{bar: "baz"}) |> exprs
    assert Macro.to_string(exprs.host) == "\"foo.com\""
  end

  test "builds a catch-all verb_match for match routes" do
    route = build(1, :match, :*, "/foo/:bar", nil, __MODULE__, :world, "hello_world", [:foo, :bar], %{foo: "bar"}, %{bar: "baz"})
    assert route.verb == :*
    assert route.kind == :match
    assert exprs(route).verb_match == {:_verb, [], nil}
  end

  test "builds a catch-all verb_match for forwarded routes" do
    route = build(1, :forward, :*, "/foo/:bar", nil, __MODULE__, :world, "hello_world", [:foo, :bar], %{foo: "bar"}, %{bar: "baz"})
    assert route.verb == :*
    assert route.kind == :forward
    assert exprs(route).verb_match == {:_verb, [], nil}
  end

  test "as a plug, it forwards and sets path_info and script_name for target, then resumes" do
    conn = %Plug.Conn{path_info: ["admin", "stats"], script_name: ["phoenix"]}
    conn = call(conn, {["admin"], AdminRouter, []})
    fwd_conn = conn.assigns[:fwd_conn]
    assert fwd_conn.path_info == ["stats"]
    assert fwd_conn.script_name == ["phoenix", "admin"]
    assert conn.path_info == ["admin", "stats"]
    assert conn.script_name == ["phoenix"]
  end

  test "exprs/1 returns quoted expressions" do
    opts = %{a: ~r/foo/}
    escaped_opts = Macro.escape(opts)

    route = build(1, :match, :*, "/foo", nil, __MODULE__, opts, "hello_world", [], %{}, %{})
    assert {__MODULE__, escaped_opts} == exprs(route).dispatch

    fwd_route = build(1, :forward, :*, "/foo", nil, __MODULE__, opts, "hello_world", [], %{}, %{})
    assert {_, {:{}, _, [_, __MODULE__, ^escaped_opts]}} = exprs(fwd_route).dispatch
  end
end
