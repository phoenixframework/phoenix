defmodule Phoenix.Router.ScopedRoutingTest do
  use ExUnit.Case
  use PlugHelper

  # Path scoping
  defmodule Admin.PostController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "post show")
  end

  defmodule ProfileController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "profiles show")
  end

  defmodule Api.V1.UserController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "api v1 users show")
  end

  defmodule EventController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "show events")
    def index(conn, _params), do: text(conn, "index events")
  end

  defmodule Api.V1.EventController do
    use Phoenix.Controller
    def destroy(conn, _params), do: text(conn, "destroy api v1 events")
  end

  defmodule Api.V1.ImageController do
    use Phoenix.Controller
    def edit(conn, _params), do: text(conn, "edit api v1 venues images")
  end

  defmodule Router do
    use Phoenix.Router
    scope path: "/admin" do
      get "/profiles/:id", ProfileController, :show, as: :profiles
    end

    scope path: "/api" do
      scope path: "/v1" do
        get "/users/:id", Api.V1.UserController, :show, as: :api_users
      end
    end

    scope path: "/admin" do
      resources "/events", EventController, only: [:show, :index]
    end

    scope path: "/api" do
      scope path: "/v1" do
        resources "/events", Api.V1.EventController, only: [:destroy]
      end
    end

    scope path: "/api" do
      scope path: "/v1" do
        resources "/venues", Api.V1.VenueController do
          resources "/images", Api.V1.ImageController, only: [:edit]
        end
      end
    end

    scope path: "/staff", alias: Staff, helper: "staff" do
      resources "/products", ProductController
    end
  end

  test "single scope for single routes" do
    conn = simulate_request(Router, :get, "/admin/profiles/1")
    assert conn.status == 200
    assert conn.resp_body == "profiles show"
    assert conn.params["id"] == "1"
  end

  test "double scope for single routes" do
    conn = simulate_request(Router, :get, "/api/v1/users/1")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "1"
  end

  test "single scope for resources" do
    conn = simulate_request(Router, :get, "/admin/events")
    assert conn.status == 200
    assert conn.resp_body == "index events"
  end

  test "single scope for resources - show action" do
    conn = simulate_request(Router, :get, "/admin/events/12")
    assert conn.status == 200
    assert conn.resp_body == "show events"
    assert conn.params["id"] == "12"
  end

  test "double scope for resources - show action" do
    conn = simulate_request(Router, :delete, "/api/v1/events/12")
    assert conn.status == 200
    assert conn.resp_body == "destroy api v1 events"
    assert conn.params["id"] == "12"
  end

  test "double scope for double nested resources - show action" do
    conn = simulate_request(Router, :get, "/api/v1/venues/12/images/13/edit")
    assert conn.status == 200
    assert conn.resp_body == "edit api v1 venues images"
    assert conn.params["venue_id"] == "12"
    assert conn.params["id"] == "13"
  end

  # Controller scoping

  defmodule Admin.UserController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "admin users show")
  end

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

    scope path: "/admin", alias: Admin do
      get "/users/:id", UserController, :show, as: :users
    end

    scope path: "/api", alias: Api do
      scope path: "/v1", alias: V1 do
        get "/users/:id", UserController, :show, as: :api_v2_users
        resources "/accounts", AccountController do
          resources "/subscriptions", SubscriptionController
        end
      end
    end

  end

  test "scope alias" do
    conn = simulate_request(RouterControllerScoping, :get, "/admin/users/12")
    assert conn.status == 200
    assert conn.resp_body == "admin users show"
    assert conn.params["id"] == "12"
  end

  test "double scope alias" do
    conn = simulate_request(RouterControllerScoping, :get, "/api/v1/users/13")
    assert conn.status == 200
    assert conn.resp_body == "api v1 users show"
    assert conn.params["id"] == "13"
  end

  test "double scope resources alias" do
    conn = simulate_request(RouterControllerScoping, :get, "/api/v1/accounts/13")
    assert conn.status == 200
    assert conn.resp_body == "api v1 accounts show"
    assert conn.params["id"] == "13"
  end

  test "double scope nested resources alias" do
    conn = simulate_request(RouterControllerScoping, :get, "/api/v1/accounts/13/subscriptions/15")
    assert conn.status == 200
    assert conn.resp_body == "api v1 accounts subscriptions show"
    assert conn.params["account_id"] == "13"
    assert conn.params["id"] == "15"
  end

  # Helper scoping

  defmodule RouterHelperScoping do
    use Phoenix.Router

    scope alias: Admin do
      get "/admin_posts/:id", PostController, :show
    end

    scope path: "/admin", alias: Admin , helper: "admin" do
      get "/users/:id", UserController, :show, as: "user"
    end

    scope path: "/api", alias: Api, helper: "api" do
      scope path: "/v1", alias: V1, helper: "v1" do
        get "/users/:id", UserController, :show, as: :api_v2_user
        resources "/accounts", AccountController do
          resources "/subscriptions", SubscriptionController
        end
      end
    end
  end

  test "single helper scope" do
    assert RouterHelperScoping.admin_user_path(:show, 88) == "/admin/users/88"
  end

  test "double helper scope" do
    assert RouterHelperScoping.api_v1_account_subscription_path(:show, 12, 88) ==
      "/api/v1/accounts/12/subscriptions/88"
  end

  test "resources actions should prefix scoped helper path" do
    assert Router.staff_product_path(:edit, 1) == "/staff/products/1/edit"
    assert Router.staff_product_path(:new) == "/staff/products/new"
  end

  test "scope does not require path argument" do
    conn = simulate_request(RouterHelperScoping, :get, "/admin_posts/123")
    assert conn.status == 200
    assert conn.params["id"] == "123"
    assert conn.resp_body == "post show"
  end
end
