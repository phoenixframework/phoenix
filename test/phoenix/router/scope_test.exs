defmodule Phoenix.Router.ScopedRoutingTest do
  use ExUnit.Case, async: true
  use ConnHelper

  setup do
    Logger.disable(self())
    :ok
  end

  # Path scoping

  defmodule ProfileController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "profiles show")
    def index(conn, _params), do: text(conn, "profiles index")
  end

  defmodule Api.V1.UserController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "api v1 users show")
    def destroy(conn, _params), do: text(conn, "api v1 users destroy")
    def edit(conn, _params), do: text(conn, "api v1 users edit")
  end

  defmodule Router do
    use Phoenix.Router

    scope "/admin" do
      get "/profiles/:id", ProfileController, :show
    end

    scope "/api" do
      scope path: "/v1" do
        get "/users/:id", Api.V1.UserController, :show
      end
    end

    scope path: "/api" do
      scope path: "/v1" do
        resources "/users", Api.V1.UserController, only: [:destroy]
      end
    end

    scope path: "/api" do
      scope path: "/v1" do
        resources "/venues", Api.V1.VenueController do
          resources "/users", Api.V1.UserController, only: [:edit]
        end
      end
    end
  end

  test "single scope for single routes" do
    conn = call(Router, :get, "/admin/profiles/1")
    assert conn.status == 200
    assert conn.resp_body == "profiles show"
    assert conn.params["id"] == "1"
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
    assert conn.resp_body == "api v1 users destroy"
    assert conn.params["id"] == "12"
  end

  test "scope for double nested resources" do
    conn = call(Router, :get, "/api/v1/venues/12/users/13/edit")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users edit"
    assert conn.params["venue_id"] == "12"
    assert conn.params["id"] == "13"
  end

  # Alias scoping

  defmodule Api.V1.AccountController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "api v1 accounts show")
  end

  defmodule Api.V1.SubscriptionController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "api v1 accounts subscriptions show")
  end

  defmodule RouterControllerScoping do
    use Phoenix.Router

    scope "/api", Api do
      get "/users/:id", V1.UserController, :show

      scope "/v1", V1, as: :api_v1 do
        resources "/accounts", AccountController do
          resources "/subscriptions", SubscriptionController
        end
      end
    end
  end

  test "scope alias" do
    conn = call(RouterControllerScoping, :get, "/api/users/13")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "13"
  end

  test "double scope resources alias" do
    conn = call(RouterControllerScoping, :get, "/api/v1/accounts/13")
    assert conn.status == 200
    assert conn.resp_body == "api v1 accounts show"
    assert conn.params["id"] == "13"
  end

  test "double scope nested resources alias" do
    conn = call(RouterControllerScoping, :get, "/api/v1/accounts/13/subscriptions/15")
    assert conn.status == 200
    assert conn.resp_body == "api v1 accounts subscriptions show"
    assert conn.params["account_id"] == "13"
    assert conn.params["id"] == "15"
  end
end
