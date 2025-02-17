defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  def init(opts), do: opts

  defmodule AdminRouter do
    def init(opts), do: opts
    def call(conn, _), do: Plug.Conn.assign(conn, :fwd_conn, conn)
  end

  test "builds a route based on verb, path, plug, plug options and helper" do
    route =
      build(
        1,
        :match,
        :get,
        "/foo/:bar",
        [],
        Hello,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{log: :debug},
        true,
        true
      )

    assert route.kind == :match
    assert route.verb == :get
    assert route.path == "/foo/:bar"
    assert route.hosts == []
    assert route.line == 1
    assert route.plug == Hello
    assert route.plug_opts == :world
    assert route.helper == "hello_world"
    assert route.pipe_through == [:foo, :bar]
    assert route.private == %{foo: "bar"}
    assert route.assigns == %{bar: "baz"}
    assert route.metadata == %{log: :debug}
    assert route.trailing_slash? == true
  end

  test "builds expressions based on the route" do
    exprs =
      build(
        1,
        :match,
        :get,
        "/foo/:bar",
        [],
        Hello,
        :world,
        "hello_world",
        [],
        %{},
        %{},
        %{},
        false,
        true
      )
      |> exprs()

    assert exprs.verb_match == "GET"
    assert exprs.path == ["foo", {:arg0, [], Phoenix.Router.Route}]
    assert exprs.binding == [{"bar", {:arg0, [], Phoenix.Router.Route}}]
    assert Macro.to_string(exprs.hosts) == "[_]"

    exprs =
      build(
        1,
        :match,
        :get,
        "/",
        ["foo."],
        Hello,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{},
        false,
        true
      )
      |> exprs()

    assert Macro.to_string(exprs.hosts) == "[\"foo.\" <> _]"

    exprs =
      build(
        1,
        :match,
        :get,
        "/",
        ["foo.", "example.com"],
        Hello,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{},
        false,
        true
      )
      |> exprs()

    assert Macro.to_string(exprs.hosts) == "[\"foo.\" <> _, \"example.com\"]"

    exprs =
      build(
        1,
        :match,
        :get,
        "/",
        ["foo.com"],
        Hello,
        :world,
        "hello_world",
        [],
        %{foo: "bar"},
        %{bar: "baz"},
        %{},
        false,
        true
      )
      |> exprs()

    assert Macro.to_string(exprs.hosts) == "[\"foo.com\"]"
  end

  test "builds a catch-all verb_match for match routes" do
    route =
      build(
        1,
        :match,
        :*,
        "/foo/:bar",
        [],
        __MODULE__,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{},
        false,
        true
      )

    assert route.verb == :*
    assert route.kind == :match
    assert exprs(route).verb_match == {:_verb, [], nil}
  end

  test "builds a catch-all verb_match for forwarded routes" do
    route =
      build(
        1,
        :forward,
        :*,
        "/foo",
        [],
        __MODULE__,
        :world,
        "hello_world",
        [:foo],
        %{foo: "bar"},
        %{bar: "baz"},
        %{forward: ~w(foo)},
        false,
        true
      )

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
end
