defmodule Phoenix.Router.ScopedRoutingTest do
  use ExUnit.Case
  use PlugHelper

  # Path scoping

  defmodule Controllers.Users do
    use Phoenix.Controller
    def show(conn), do: text(conn, "users show")
  end

  defmodule Controllers.Api.V1.Users do
    use Phoenix.Controller
    def show(conn), do: text(conn, "api users show")
  end

  defmodule Controllers.Events do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show events")
    def index(conn), do: text(conn, "index events")
  end

  defmodule Controllers.Api.V1.Events do
    use Phoenix.Controller
    def destroy(conn), do: text(conn, "destroy api v1 events")
  end

  defmodule Controllers.Api.V1.Images do
    use Phoenix.Controller
    def edit(conn), do: text(conn, "edit api v1 venues images")
  end

  defmodule Router do
    use Phoenix.Router
    scope path: "admin" do
      get "users/:id", Controllers.Users, :show, as: :user
    end

    scope path: "api" do
      scope path: "v1" do
        get "users/:id", Controllers.Api.V1.Users, :show, as: :api_user
      end
    end

    scope path: "admin" do
      resources "events", Controllers.Events, only: [:show, :index]
    end

    scope path: "api" do
      scope path: "v1" do
        resources "events", Controllers.Api.V1.Events, only: [:destroy]
      end
    end

    scope path: "api" do
      scope path: "v1" do
        resources "venues", Controllers.Api.V1.Venues do
          resources "images", Controllers.Api.V1.Images, only: [:edit]
        end
      end
    end
  end

  test "single scope for single routes" do
    conn = simulate_request(Router, :get, "/admin/users/1")
    assert conn.status == 200
    assert conn.resp_body == "users show"
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

  defmodule Controllers.Admin.Users do
    use Phoenix.Controller
    def show(conn), do: text(conn, "admin users show")
  end

  defmodule Controllers.Api.V1.Users do
    use Phoenix.Controller
    def show(conn), do: text(conn, "api v1 users show")
  end

  defmodule Controllers.Api.V1.Accounts do
    use Phoenix.Controller
    def show(conn), do: text(conn, "api v1 accounts show")
  end

  defmodule Controllers.Api.V1.Subscriptions do
    use Phoenix.Controller
    def show(conn), do: text(conn, "api v1 accounts subscriptions show")
  end

  defmodule RouterControllerScoping do
    use Phoenix.Router

    scope path: "admin", alias: Controllers.Admin do
      get "users/:id", Users, :show, as: :user
    end

    scope path: "api", alias: Controllers.Api do
      scope path: "v1", alias: V1 do
        get "users/:id", Users, :show, as: :api_v2_user
        resources "accounts", Accounts do
          resources "subscriptions", Subscriptions
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

  test "double scope nasted resources alias" do
    conn = simulate_request(RouterControllerScoping, :get, "/api/v1/accounts/13/subscriptions/15")
    assert conn.status == 200
    assert conn.resp_body == "api v1 accounts subscriptions show"
    assert conn.params["account_id"] == "13"
    assert conn.params["id"] == "15"
  end

  # Helper scoping

  defmodule RouterHelperScoping do
    use Phoenix.Router

    scope path: "admin", alias: Controllers.Admin , helper: "admin" do
      get "users/:id", Users, :show, as: :user
    end

    scope path: "api", alias: Controllers.Api, helper: "api" do
      scope path: "v1", alias: V1, helper: "v1" do
        get "users/:id", Users, :show, as: :api_v2_user
        resources "accounts", Accounts do
          resources "subscriptions", Subscriptions
        end
      end
    end
  end

  test "single helper scope" do
    assert RouterHelperScoping.admin_user_path(id: 88) == "/admin/users/88"
  end

  test "double helper scope" do
    assert RouterHelperScoping.api_v1_account_subscription_path(account_id: 12, id: 88) ==
      "/api/v1/accounts/12/subscriptions/88"
  end

end
