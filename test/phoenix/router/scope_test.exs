defmodule Phoenix.Router.ScopedRoutingTest do
  use ExUnit.Case, async: true
  use RouterHelper

  # Path scoping

  defmodule Api.V1.UserController do
    use Phoenix.Controller, formats: []
    def show(conn, _params), do: text(conn, "api v1 users show")
    def delete(conn, _params), do: text(conn, "api v1 users delete")
    def edit(conn, _params), do: text(conn, "api v1 users edit")
    def foo_host(conn, _params), do: text(conn, "foo request from #{conn.host}")
    def baz_host(conn, _params), do: text(conn, "baz request from #{conn.host}")
    def multi_host(conn, _params), do: text(conn, "multi_host request from #{conn.host}")

    def other_subdomain(conn, _params),
      do: text(conn, "other_subdomain request from #{conn.host}")

    def proxy(conn, _) do
      {controller, action} = conn.private.proxy_to
      controller.call(conn, controller.init(action))
    end
  end

  defmodule Api.V1.VenueController do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmodule :erlang_like do
    def init(action), do: action
    def call(conn, action), do: Plug.Conn.send_resp(conn, 200, "Erlang like #{action}")
  end

  defmodule Router do
    use Phoenix.Router

    scope "/admin", host: "baz." do
      get "/users/:id", Api.V1.UserController, :baz_host
    end

    scope host: "foobar.com" do
      scope "/admin" do
        get "/users/:id", Api.V1.UserController, :foo_host
      end
    end

    scope "/admin" do
      get "/erlang/like", :erlang_like, :action, as: :erlang_like
      get "/users/:id", Api.V1.UserController, :show
    end

    scope "/api" do
      scope "/v1" do
        get "/users/:id", Api.V1.UserController, :show
      end
    end

    scope "/api", Api, private: %{private_token: "foo"} do
      get "/users", V1.UserController, :show
      get "/users/:id", V1.UserController, :show, private: %{private_token: "bar"}

      scope "/v1", alias: V1 do
        resources "/users", UserController, only: [:delete], private: %{private_token: "baz"}

        get "/noalias", Api.V1.UserController, :proxy,
          private: %{proxy_to: {scoped_alias(__MODULE__, UserController), :show}},
          alias: false

        scope "/scoped", alias: false do
          get "/noalias", Api.V1.UserController, :proxy,
            private: %{proxy_to: {scoped_alias(__MODULE__, Api.V1.UserController), :show}}
        end
      end
    end

    scope "/assigns", Api, assigns: %{assigns_token: "foo"} do
      get "/users", V1.UserController, :show
      get "/users/:id", V1.UserController, :show, assigns: %{assigns_token: "bar"}

      scope "/v1", alias: V1 do
        resources "/users", UserController, only: [:delete], assigns: %{assigns_token: "baz"}
      end
    end

    scope "/host", host: "baz." do
      get "/users/:id", Api.V1.UserController, :baz_host
    end

    scope host: "foobar.com" do
      scope "/host" do
        get "/users/:id", Api.V1.UserController, :foo_host
      end
    end

    scope "/api" do
      scope "/v1", Api do
        resources "/venues", V1.VenueController, only: [:show], alias: V1 do
          resources "/users", UserController, only: [:edit]
        end
      end
    end

    # match www, no subdomain, and localhost
    scope "/multi_host", host: ["www.", "example.com", "localhost"] do
      get "/", Api.V1.UserController, :multi_host
    end

    # matched logged in subdomain user homepages
    scope "/multi_host" do
      get "/", Api.V1.UserController, :other_subdomain
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "single scope for single routes" do
    conn = call(Router, :get, "/admin/users/1")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "1"

    conn = call(Router, :get, "/api/users/13")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "13"
  end

  test "single scope with Erlang like route" do
    conn = call(Router, :get, "/admin/erlang/like")
    assert conn.status == 200
    assert conn.resp_body == "Erlang like action"
  end

  test "double scope for single routes" do
    conn = call(Router, :get, "/api/v1/users/1")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "1"
  end

  test "scope for resources" do
    conn = call(Router, :delete, "/api/v1/users/12")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users delete"
    assert conn.params["id"] == "12"
  end

  test "scope for double nested resources" do
    conn = call(Router, :get, "/api/v1/venues/12/users/13/edit")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users edit"
    assert conn.params["venue_id"] == "12"
    assert conn.params["id"] == "13"
  end

  test "host scopes routes based on conn.host" do
    conn = call(Router, :get, "http://foobar.com/admin/users/1")
    assert conn.status == 200
    assert conn.resp_body == "foo request from foobar.com"
    assert conn.params["id"] == "1"
  end

  test "host scopes allows partial host matching" do
    conn = call(Router, :get, "http://baz.bing.com/admin/users/1")
    assert conn.status == 200
    assert conn.resp_body == "baz request from baz.bing.com"

    conn = call(Router, :get, "http://baz.pang.com/admin/users/1")
    assert conn.status == 200
    assert conn.resp_body == "baz request from baz.pang.com"
  end

  test "host scopes allows list of hosts" do
    conn = call(Router, :get, "http://www.example.com/multi_host")
    assert conn.status == 200
    assert conn.resp_body == "multi_host request from www.example.com"

    conn = call(Router, :get, "http://www.anotherwww.com/multi_host")
    assert conn.status == 200
    assert conn.resp_body == "multi_host request from www.anotherwww.com"

    conn = call(Router, :get, "http://localhost/multi_host")
    assert conn.status == 200
    assert conn.resp_body == "multi_host request from localhost"

    conn = call(Router, :get, "http://subdomain.example.com/multi_host")
    assert conn.status == 200
    assert conn.resp_body == "other_subdomain request from subdomain.example.com"
  end

  test "host 404s when failed match" do
    conn = call(Router, :get, "http://foobar.com/host/users/1")
    assert conn.status == 200

    conn = call(Router, :get, "http://baz.pang.com/host/users/1")
    assert conn.status == 200

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :get, "http://foobar.com.br/host/users/1")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :get, "http://ba.pang.com/host/users/1")
    end
  end

  test "bad host raises" do
    assert_raise ArgumentError,
                 "expected router scope :host to be compile-time string or list of strings, got: nil",
                 fn ->
                   defmodule BadRouter do
                     use Phoenix.Router

                     scope "/admin", host: ["foo.", nil] do
                       get "/users/:id", Api.V1.UserController, :baz_host
                     end
                   end
                 end
  end

  test "private data in scopes" do
    conn = call(Router, :get, "/api/users")
    assert conn.status == 200
    assert conn.private[:private_token] == "foo"

    conn = call(Router, :get, "/api/users/13")
    assert conn.status == 200
    assert conn.private[:private_token] == "bar"

    conn = call(Router, :delete, "/api/v1/users/13")
    assert conn.status == 200
    assert conn.private[:private_token] == "baz"
  end

  test "assigns data in scopes" do
    conn = call(Router, :get, "/assigns/users")
    assert conn.status == 200
    assert conn.assigns[:assigns_token] == "foo"

    conn = call(Router, :get, "/assigns/users/13")
    assert conn.status == 200
    assert conn.assigns[:assigns_token] == "bar"

    conn = call(Router, :delete, "/assigns/v1/users/13")
    assert conn.status == 200
    assert conn.assigns[:assigns_token] == "baz"
  end

  test "string paths are enforced" do
    assert_raise ArgumentError, ~r{router paths must be strings, got: :bar}, fn ->
      defmodule SomeRouter do
        use Phoenix.Router, otp_app: :phoenix
        get :bar, Router, []
      end
    end

    assert_raise ArgumentError, ~r{router paths must be strings, got: :bar}, fn ->
      defmodule SomeRouter do
        use Phoenix.Router, otp_app: :phoenix
        get "/foo", Router, []

        scope "/another" do
          resources :bar, Router, []
        end
      end
    end
  end

  test "alias false with expanded scoped alias via option" do
    conn = call(Router, :get, "/api/v1/noalias")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
  end

  test "alias false with expanded scoped alias via scope" do
    conn = call(Router, :get, "/api/v1/scoped/noalias")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
  end

  test "raises for reserved prefixes" do
    assert_raise ArgumentError, ~r/`static` is a reserved route prefix/, fn ->
      defmodule ErrorRouter do
        use Phoenix.Router

        scope "/" do
          get "/", StaticController, :index
        end
      end
    end

    assert_raise ArgumentError, ~r/`static` is a reserved route prefix/, fn ->
      defmodule ErrorRouter do
        use Phoenix.Router

        scope "/" do
          get "/", Api.V1.UserController, :show, as: :static
        end
      end
    end
  end
end
