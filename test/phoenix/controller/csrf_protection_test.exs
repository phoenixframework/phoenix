defmodule Phoenix.Controller.CsrfProtectionTest do
  use ExUnit.Case
  use RouterHelper
  alias Phoenix.Controller.CsrfProtectionTest.Router
  alias Phoenix.Plugs.CsrfProtection

  setup_all do
    Mix.Config.persist(phoenix: [
      {Router,
        cookies: true,
        session_key: "_app",
        session_secret: "111111111111111111111111111111111111111111111111111111111111111111111111111",
        csrf_protection: true
      }
    ])

    defmodule Controller do
      use Phoenix.Controller

      plug :action

      def index(conn, _params) do
        text conn, "hello"
      end
      def create(conn, _params), do: conn
      def update(conn, _params), do: conn
      def destroy(conn, _params), do: conn
    end

    defmodule Router do
      use Phoenix.Router
      plug :plant_token

      def plant_token(conn, _opts) do
        conn = Conn.put_session(conn, :csrf_token, "hello123")
        conn
      end

      resources "/csrf", Controller
    end

    :ok
  end

  setup do
    conn = simulate_request(Router, :get, "index")
    :ok
  end

  test "raises error for invalid authenticity token" do
    params = %{first_name: "Foo", csrf_token: "12"}
    assert_raise RuntimeError, fn ->
      simulate_request Router, :post, "create", params
    end
    assert_raise RuntimeError, fn ->
      simulate_request Router, :post, "create", %{}
    end
  end

  test "unprotected requests are always valid" do
    simulate_request(Router, :get, "index")
    simulate_request(Router, :options, "index")
    simulate_request(Router, :connect, "index")
    simulate_request(Router, :trace, "index")
    simulate_request(Router, :head, "index")
  end

  test "protected requests with valid tokens are allowed", context do
    simulate_request(Router, :post, "create", %{csrf_token: "hello123"})
    simulate_request(Router, :put, "update", %{csrf_token: "hello123"})
    simulate_request(Router, :delete, "destroy", %{csrf_token: "hello123"})
    simulate_request(Router, :patch, "update", %{csrf_token: "hello123"})
  end
end
