defmodule Phoenix.Router.GroupByTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Controller do
    use Phoenix.Controller, formats: []

    def index(conn, _params), do: text(conn, "index")
    def show(conn, _params), do: text(conn, "show #{conn.params["id"]}")
    def files(conn, _params), do: text(conn, Enum.join(conn.params["path"], "/"))
    def host(conn, _params), do: text(conn, "host #{conn.host}")
    def create(conn, _params), do: text(conn, "create")
    def any(conn, _params), do: text(conn, "any")
  end

  defmodule Router do
    use Phoenix.Router, group_by: :verb

    get "/", Controller, :index, metadata: %{page: :index}
    post "/", Controller, :create, metadata: %{page: :create}
    get "/users/:id", Controller, :show, metadata: %{page: :show}
    get "/files/*path", Controller, :files, metadata: %{page: :files}

    scope "/", host: "api." do
      get "/host", Controller, :host, metadata: %{page: :host}
    end

    match :*, "/any", Controller, :any, metadata: %{page: :any}
  end

  test "dispatches static, dynamic, glob, host, and catch-all verb routes" do
    assert call(Router, :get, "/").resp_body == "index"
    assert call(Router, :post, "/").resp_body == "create"
    assert call(Router, :get, "/users/123").resp_body == "show 123"
    assert call(Router, :get, "/files/foo/bar").resp_body == "foo/bar"
    assert call(Router, :post, "/any").resp_body == "any"

    conn =
      :get
      |> conn("/host")
      |> Map.put(:host, "api.example.com")
      |> Router.call(Router.init([]))

    assert conn.resp_body == "host api.example.com"
  end

  test "route_info returns metadata and path params" do
    assert Phoenix.Router.route_info(Router, "GET", "/users/123", nil) == %{
             log: :debug,
             page: :show,
             path_params: %{"id" => "123"},
             pipe_through: [],
             plug: Controller,
             plug_opts: :show,
             route: "/users/:id"
           }

    assert Phoenix.Router.route_info(Router, "GET", "/files/foo/bar", nil) == %{
             log: :debug,
             page: :files,
             path_params: %{"path" => ["foo", "bar"]},
             pipe_through: [],
             plug: Controller,
             plug_opts: :files,
             route: "/files/*path"
           }

    assert Phoenix.Router.route_info(Router, "GET", "/host", "api.example.com") == %{
             log: :debug,
             page: :host,
             path_params: %{},
             pipe_through: [],
             plug: Controller,
             plug_opts: :host,
             route: "/host"
           }
  end

  test "raises when explicit routes are defined after match :* or forward" do
    match_error =
      assert_raise CompileError, fn ->
        defmodule InvalidMatchRouter do
          use Phoenix.Router, group_by: :verb

          match :*, "/any", Controller, :any
          get "/users/:id", Controller, :show
          post "/files/*path", Controller, :files
        end
      end

    assert Exception.message(match_error) =~
             "cannot compile router with group_by: :verb because routes were found after a match :* or forward"

    assert Exception.message(match_error) =~ ~s|"/users/:id" after match :*, "/any"|
    assert Exception.message(match_error) =~ ~s|"/files/*path" after match :*, "/any"|

    forward_error =
      assert_raise CompileError, fn ->
        defmodule InvalidForwardRouter do
          use Phoenix.Router, group_by: :verb

          forward "/admin", Router
          get "/admin/stats", Controller, :index
        end
      end

    assert Exception.message(forward_error) =~ ~s|"/admin/stats" after forward "/admin"|
  end
end
