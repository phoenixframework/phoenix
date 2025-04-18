defmodule Phoenix.Router.RoutingTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import ExUnit.CaptureLog

  defmodule SomePlug do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmodule UserController do
    use Phoenix.Controller, formats: []
    def index(conn, _params), do: text(conn, "users index")
    def show(conn, _params), do: text(conn, "users show")
    def top(conn, _params), do: text(conn, "users top")
    def options(conn, _params), do: text(conn, "users options")
    def connect(conn, _params), do: text(conn, "users connect")
    def trace(conn, _params), do: text(conn, "users trace")
    def not_found(conn, _params), do: text(put_status(conn, :not_found), "not found")
    def image(conn, _params), do: text(conn, conn.params["path"] || "show files")
    def move(conn, _params), do: text(conn, "users move")
    def any(conn, _params), do: text(conn, "users any")
    def raise(_conn, _params), do: raise("boom")
    def exit(_conn, _params), do: exit(:boom)

    def halt(conn, _params) do
      conn
      |> send_resp(401, "Unauthorized")
      |> halt()
    end
  end

  defmodule LogLevel do
    def log_level(%{params: %{"level" => "info"}}), do: :info
    def log_level(%{params: %{"level" => "error"}}), do: :error
    def log_level(_), do: :debug
  end

  defmodule Router do
    use Phoenix.Router

    get "/", UserController, :index, as: :users
    get "/users/top", UserController, :top, as: :top
    get "/users/:id", UserController, :show, as: :users, metadata: %{access: :user}
    match :*, "/users/fallback", UserController, :any
    get "/spaced users/:id", UserController, :show
    get "/profiles/profile-:id", UserController, :show
    get "/route_that_crashes", UserController, :crash
    get "/files/:user_name/*path", UserController, :image
    get "/backups/*path", UserController, :image
    get "/static/images/icons/*image", UserController, :image
    get "/exit", UserController, :exit
    get "/halt-controller", UserController, :halt

    trace("/trace", UserController, :trace)
    options "/options", UserController, :options
    connect "/connect", UserController, :connect
    match :move, "/move", UserController, :move
    match :*, "/any", UserController, :any

    scope log: :info do
      pipe_through :noop
      get "/plug", SomePlug, []
      get "/users/:id/raise", UserController, :raise
      pipe_through :halt
      get "/info", UserController, :raise
    end

    get "/no_log", SomePlug, [], log: false
    get "/fun_log", SomePlug, [], log: {LogLevel, :log_level, []}
    get "/override-plug-name", SomePlug, :action, metadata: %{mfa: {LogLevel, :log_level, 1}}
    get "/users/:user_id/files/:id", UserController, :image

    scope "/halt-plug" do
      pipe_through :halt
      get "/", UserController, :raise
    end

    get "/*path", UserController, :not_found

    defp noop(conn, _), do: conn

    defp halt(conn, _) do
      conn |> Plug.Conn.send_resp(401, "Unauthorized") |> halt()
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "get root path" do
    conn = call(Router, :get, "/")
    assert conn.status == 200
    assert conn.resp_body == "users index"
  end

  test "get to named param with dashes" do
    conn = call(Router, :get, "/users/75f6306d-a090-46f9-8b80-80fd57ec9a41")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "75f6306d-a090-46f9-8b80-80fd57ec9a41"
    assert conn.path_params["id"] == "75f6306d-a090-46f9-8b80-80fd57ec9a41"

    conn = call(Router, :get, "/users/75f6306d-a0/files/34-95")
    assert conn.status == 200
    assert conn.resp_body == "show files"
    assert conn.params["user_id"] == "75f6306d-a0"
    assert conn.path_params["user_id"] == "75f6306d-a0"
    assert conn.params["id"] == "34-95"
    assert conn.path_params["id"] == "34-95"
  end

  test "get with named param" do
    conn = call(Router, :get, "/users/1")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
    assert conn.path_params["id"] == "1"
  end

  test "get with named param and late query string fetch" do
    conn =
      conn(:get, "/users/1")
      |> Router.call(Router.init([]))
      |> fetch_query_params()

    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
    assert conn.path_params["id"] == "1"

    conn =
      conn(:get, "/users/1?foo=bar")
      |> Router.call(Router.init([]))
      |> fetch_query_params()

    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
    assert conn.params["foo"] == "bar"
    assert conn.path_params["id"] == "1"
  end

  test "parameters are url decoded" do
    conn = call(Router, :get, "/users/hello%20matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/spaced%20users/hello%20matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/spaced users/hello matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/users/a%20b")
    assert conn.params == %{"id" => "a b"}

    conn = call(Router, :get, "/backups/a%20b/c%20d")
    assert conn.params == %{"path" => ["a b", "c d"]}
  end

  test "get to custom action" do
    conn = call(Router, :get, "/users/top")
    assert conn.status == 200
    assert conn.resp_body == "users top"
  end

  test "options to custom action" do
    conn = call(Router, :options, "/options")
    assert conn.status == 200
    assert conn.resp_body == "users options"
  end

  test "connect to custom action" do
    conn = call(Router, :connect, "/connect")
    assert conn.status == 200
    assert conn.resp_body == "users connect"
  end

  test "trace to custom action" do
    conn = call(Router, :trace, "/trace")
    assert conn.status == 200
    assert conn.resp_body == "users trace"
  end

  test "splat arg with preceding named parameter to files/:user_name/*path" do
    conn = call(Router, :get, "/files/elixir/Users/home/file.txt")
    assert conn.status == 200
    assert conn.params["user_name"] == "elixir"
    assert conn.params["path"] == ["Users", "home", "file.txt"]
  end

  test "splat arg with preceding string to backups/*path" do
    conn = call(Router, :get, "/backups/name")
    assert conn.status == 200
    assert conn.params["path"] == ["name"]
  end

  test "splat arg with multiple preceding strings to static/images/icons/*path" do
    conn = call(Router, :get, "/static/images/icons/elixir/logos/main.png")
    assert conn.status == 200
    assert conn.params["image"] == ["elixir", "logos", "main.png"]
  end

  test "splat args are %encodings in path" do
    conn = call(Router, :get, "/backups/silly%20name")
    assert conn.status == 200
    assert conn.params["path"] == ["silly name"]
  end

  test "catch-all splat route matches" do
    conn = call(Router, :get, "/foo/bar/baz")
    assert conn.status == 404
    assert conn.params == %{"path" => ~w"foo bar baz"}
    assert conn.resp_body == "not found"
  end

  test "match on arbitrary http methods" do
    conn = call(Router, :move, "/move")
    assert conn.method == "MOVE"
    assert conn.status == 200
    assert conn.resp_body == "users move"
  end

  test "any verb matches" do
    conn = call(Router, :get, "/any")
    assert conn.method == "GET"
    assert conn.status == 200
    assert conn.resp_body == "users any"

    conn = call(Router, :put, "/any")
    assert conn.method == "PUT"
    assert conn.status == 200
    assert conn.resp_body == "users any"
  end

  test "different verbs with similar paths" do
    conn = call(Router, :post, "/users/fallback")
    assert conn.status == 200
    assert conn.resp_body == "users any"

    conn = call(Router, :get, "/users/123")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "123"
    assert conn.path_params["id"] == "123"
  end

  describe "logging" do
    setup do
      Logger.enable(self())
      :ok
    end

    test "logs controller and action with (path) parameters" do
      assert capture_log(fn -> call(Router, :get, "/users/1", foo: "bar") end) =~ """
             [debug] Processing with Phoenix.Router.RoutingTest.UserController.show/2
               Parameters: %{"foo" => "bar", "id" => "1"}
               Pipelines: []
             """
    end

    test "logs controller and action with filtered parameters" do
      assert capture_log(fn -> call(Router, :get, "/users/1", password: "bar") end) =~ """
             [debug] Processing with Phoenix.Router.RoutingTest.UserController.show/2
               Parameters: %{"id" => "1", "password" => "[FILTERED]"}
               Pipelines: []
             """
    end

    test "logs plug with pipeline and custom level" do
      assert capture_log(fn -> call(Router, :get, "/plug") end) =~ """
             [info] Processing with Phoenix.Router.RoutingTest.SomePlug
               Parameters: %{}
               Pipelines: [:noop]
             """
    end

    test "does not log when log is set to false" do
      refute capture_log(fn -> call(Router, :get, "/no_log", foo: "bar") end) =~
               "Processing with Phoenix.Router.RoutingTest.SomePlug"
    end

    test "overrides plug name that processes the route when set in metadata" do
      assert capture_log(fn -> call(Router, :get, "/override-plug-name") end) =~
               "Processing with Phoenix.Router.RoutingTest.LogLevel.log_level/1"
    end

    test "logs custom level when log is set to a 1-arity function" do
      assert capture_log(fn -> call(Router, :get, "/fun_log", level: "info") end) =~
               "[info] Processing with Phoenix.Router.RoutingTest.SomePlug"

      assert capture_log(fn -> call(Router, :get, "/fun_log", level: "error") end) =~
               "[error] Processing with Phoenix.Router.RoutingTest.SomePlug"

      assert capture_log(fn -> call(Router, :get, "/fun_log", level: "yelling") end) =~
               "[debug] Processing with Phoenix.Router.RoutingTest.SomePlug"

      assert capture_log(fn -> call(Router, :get, "/fun_log") end) =~
               "[debug] Processing with Phoenix.Router.RoutingTest.SomePlug"
    end
  end

  describe "telemetry" do
    @router_start_event [:phoenix, :router_dispatch, :start]
    @router_stop_event [:phoenix, :router_dispatch, :stop]
    @router_exception_event [:phoenix, :router_dispatch, :exception]
    @router_events [
      @router_start_event,
      @router_stop_event,
      @router_exception_event
    ]

    setup context do
      test_pid = self()
      test_name = context.test

      :telemetry.attach_many(
        test_name,
        @router_events,
        fn event, measures, metadata, config ->
          send(test_pid, {:telemetry_event, event, {measures, metadata, config}})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(test_name) end)
    end

    test "phoenix.router_dispatch.start and .stop are emitted on success" do
      call(Router, :get, "/users/123")

      assert_received {:telemetry_event, @router_start_event, {_, %{route: "/users/:id"}, _}}

      assert_received {:telemetry_event, @router_stop_event, {_, %{route: "/users/:id"}, _}}

      refute_received {:telemetry_event, @router_exception_event, {_, %{route: "/users/:id"}, _}}
    end

    test "phoenix.router_dispatch.start and .stop are emitted when conn halted in router" do
      conn = call(Router, :get, "/halt-plug")

      assert conn.halted
      assert conn.status == 401

      assert_received {:telemetry_event, @router_start_event, {_, %{route: "/halt-plug"}, _}}

      assert_received {:telemetry_event, @router_stop_event, {_, %{route: "/halt-plug"}, _}}

      refute_received {:telemetry_event, @router_exception_event, {_, %{route: "/halt-plug"}, _}}
    end

    test "phoenix.router_dispatch.start and .stop are emitted when conn is halted in controller" do
      conn = call(Router, :get, "/halt-controller")

      assert conn.halted
      assert conn.status == 401

      assert_received {:telemetry_event, @router_start_event,
                       {_, %{route: "/halt-controller"}, _}}

      assert_received {:telemetry_event, @router_stop_event, {_, %{route: "/halt-controller"}, _}}

      refute_received {:telemetry_event, @router_exception_event,
                       {_, %{route: "/halt-controller"}, _}}
    end

    test "phoenix.router_dispatch.start and .exception are emitted on crash" do
      assert_raise Plug.Conn.WrapperError, ~r/UndefinedFunctionError/, fn ->
        call(Router, :get, "/route_that_crashes")
      end

      assert_received {:telemetry_event, @router_start_event,
                       {_, %{route: "/route_that_crashes"}, _}}

      assert_received {:telemetry_event, @router_exception_event,
                       {_, %{route: "/route_that_crashes"}, _}}

      refute_received {:telemetry_event, @router_stop_event,
                       {_, %{route: "/route_that_crashes"}, _}}
    end

    test "phoenix.router_dispatch.start and .exception are emitted on exit" do
      catch_exit(call(Router, :get, "/exit"))

      assert_received {:telemetry_event, @router_start_event, {_, %{route: "/exit"}, _}}

      assert_received {:telemetry_event, @router_exception_event, {_, %{route: "/exit"}, _}}

      refute_received {:telemetry_event, @router_stop_event, {_, %{route: "/exit"}, _}}
    end

    test "phoenix.router_dispatch.start has supported measurements and metadata" do
      call(Router, :get, "/users/123")

      assert_received {:telemetry_event, @router_start_event,
                       {measures, %{route: "/users/:id"} = meta, _config}}

      assert is_integer(measures.system_time)

      assert %{
               access: :user,
               conn: %Plug.Conn{state: :unset},
               log: :debug,
               path_params: %{"id" => "123"},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :show,
               route: "/users/:id"
             } = meta
    end

    test "phoenix.router_dispatch.stop has supported measurements and metadata" do
      call(Router, :get, "/users/123")

      assert_received {:telemetry_event, @router_stop_event,
                       {measures, %{route: "/users/:id"} = meta, _config}}

      assert is_integer(measures.duration)

      assert %{
               access: :user,
               conn: %Plug.Conn{state: :sent},
               log: :debug,
               path_params: %{"id" => "123"},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :show,
               route: "/users/:id"
             } = meta
    end

    test "phoenix.router_dispatch.exception has supported measurements and metadata on crash" do
      assert_raise Plug.Conn.WrapperError, "** (RuntimeError) boom", fn ->
        call(Router, :get, "/users/123/raise")
      end

      assert_received {:telemetry_event, @router_exception_event,
                       {measures, %{route: "/users/:id/raise"} = meta, _config}}

      assert is_integer(measures.duration)

      assert %{
               conn: %Plug.Conn{state: :unset},
               kind: :error,
               log: :info,
               path_params: %{"id" => "123"},
               pipe_through: [:noop],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :raise,
               reason: %Plug.Conn.WrapperError{
                 conn: %Plug.Conn{state: :unset},
                 kind: :error,
                 reason: %RuntimeError{message: "boom"},
                 stack: wrapped_stacktrace
               },
               route: "/users/:id/raise",
               stacktrace: stacktrace
             } = meta

      assert is_list(wrapped_stacktrace) && length(wrapped_stacktrace) > 0
      assert is_list(stacktrace) && length(stacktrace) > 0
    end

    test "phoenix.router_dispatch.exception has supported measurements and metadata on exit" do
      catch_exit(call(Router, :get, "/exit"))

      assert_received {:telemetry_event, @router_exception_event,
                       {measures, %{route: "/exit"} = meta, _config}}

      assert is_integer(measures.duration)

      assert %{
               conn: %Plug.Conn{state: :unset},
               kind: :exit,
               log: :debug,
               path_params: %{},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :exit,
               reason: :boom,
               route: "/exit",
               stacktrace: stacktrace
             } = meta

      assert is_list(stacktrace) && length(stacktrace) > 0
    end
  end

  describe "route_info" do
    test " returns route string, path params, and more" do
      assert Phoenix.Router.route_info(Router, "GET", "foo/bar/baz", nil) == %{
               log: :debug,
               path_params: %{"path" => ["foo", "bar", "baz"]},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :not_found,
               route: "/*path"
             }

      assert Phoenix.Router.route_info(Router, "GET", "users/1", nil) == %{
               log: :debug,
               path_params: %{"id" => "1"},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :show,
               route: "/users/:id",
               access: :user
             }

      assert Phoenix.Router.route_info(Router, "GET", "/", "host") == %{
               log: :debug,
               path_params: %{},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :index,
               route: "/"
             }

      assert Phoenix.Router.route_info(Router, "POST", "/not-exists", "host") == :error
    end

    test "returns route string, path params and more for split path" do
      assert Phoenix.Router.route_info(Router, "GET", ~w(foo bar baz), nil) == %{
               log: :debug,
               path_params: %{"path" => ["foo", "bar", "baz"]},
               pipe_through: [],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :not_found,
               route: "/*path"
             }
    end

    test "returns accumulated pipe_through metadata" do
      assert Phoenix.Router.route_info(Router, "GET", "/info", nil) == %{
               log: :info,
               path_params: %{},
               pipe_through: [:noop, :halt],
               plug: Phoenix.Router.RoutingTest.UserController,
               plug_opts: :raise,
               route: "/info"
             }
    end
  end
end
