defmodule Phoenix.Router.PipeThroughDeprecationTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import ExUnit.CaptureLog

  defmodule UserController do
    use Phoenix.Controller, formats: []
    def index(conn, _params), do: text(conn, "users index")
    def show(conn, _params), do: text(conn, "users show")
  end

  defmodule SomePlug do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  describe "pipe_through deprecation warning" do
    setup do
      Logger.enable(self())
      :ok
    end

    test "warns when pipe_through is called after routes are defined" do
      log =
        capture_log(fn ->
          defmodule TestRouter1 do
            use Phoenix.Router

            scope "/" do
              get "/", UserController, :index
              pipe_through [:browser]
              get "/users", UserController, :show
            end

            defp browser(conn, _), do: conn
          end
        end)

      assert log =~ "Calling pipe_through/1 after defining routes is deprecated"

      assert log =~
               "Routes defined before pipe_through/1 will not have the specified pipelines applied"

      assert log =~ "pipe_through [:browser] was called after them"
      assert log =~ "Move all pipe_through/1 calls to the beginning of the scope block"
    end

    test "warns when pipe_through is called after multiple routes" do
      log =
        capture_log(fn ->
          defmodule TestRouter2 do
            use Phoenix.Router

            scope "/" do
              get "/", UserController, :index
              get "/about", UserController, :show
              pipe_through [:browser, :auth]
              get "/users", UserController, :show
            end

            defp browser(conn, _), do: conn
            defp auth(conn, _), do: conn
          end
        end)

      assert log =~ "Calling pipe_through/1 after defining routes is deprecated"
      assert log =~ "pipe_through [:browser, :auth] was called after them"
    end

    test "does not warn when pipe_through is called before routes" do
      log =
        capture_log(fn ->
          defmodule TestRouter3 do
            use Phoenix.Router

            scope "/" do
              pipe_through [:browser]
              get "/", UserController, :index
              get "/users", UserController, :show
            end

            defp browser(conn, _), do: conn
          end
        end)

      refute log =~ "Calling pipe_through/1 after defining routes is deprecated"
    end

    test "does not warn when pipe_through is the only thing in a scope" do
      log =
        capture_log(fn ->
          defmodule TestRouter4 do
            use Phoenix.Router

            scope "/" do
              pipe_through [:browser]
            end

            defp browser(conn, _), do: conn
          end
        end)

      refute log =~ "Calling pipe_through/1 after defining routes is deprecated"
    end

    test "warns for each scope independently" do
      log =
        capture_log(fn ->
          defmodule TestRouter5 do
            use Phoenix.Router

            scope "/admin" do
              pipe_through [:browser]
              get "/", UserController, :index
            end

            scope "/api" do
              get "/users", UserController, :show
              pipe_through [:api]
              get "/posts", UserController, :index
            end

            defp browser(conn, _), do: conn
            defp api(conn, _), do: conn
          end
        end)

      # Should only warn for the /api scope, not /admin
      assert log =~ "Calling pipe_through/1 after defining routes is deprecated"
      assert log =~ "pipe_through [:api] was called after them"
      # Should only appear once since only one scope has the issue
      assert String.split(log, "Calling pipe_through/1 after defining routes is deprecated")
             |> length() == 2
    end

    test "warns when pipe_through is called multiple times after routes" do
      log =
        capture_log(fn ->
          defmodule TestRouter6 do
            use Phoenix.Router

            scope "/" do
              get "/", UserController, :index
              pipe_through [:browser]
              get "/users", UserController, :show
              pipe_through [:auth]
              get "/admin", UserController, :index
            end

            defp browser(conn, _), do: conn
            defp auth(conn, _), do: conn
          end
        end)

      # Should warn twice - once for each pipe_through after routes
      warnings = String.split(log, "Calling pipe_through/1 after defining routes is deprecated")
      # Original string plus 2 splits = 3 parts
      assert length(warnings) == 3

      assert log =~ "pipe_through [:browser] was called after them"
      assert log =~ "pipe_through [:auth] was called after them"
    end

    test "router still functions correctly despite warning" do
      # Capture and discard the warning log
      capture_log(fn ->
        defmodule TestRouter7 do
          use Phoenix.Router

          scope "/" do
            get "/first", UserController, :index
            pipe_through [:browser]
            get "/second", UserController, :show
          end

          defp browser(conn, _), do: assign(conn, :browser_called, true)
        end
      end)

      # Test that routing still works
      conn = call(Phoenix.Router.PipeThroughDeprecationTest.TestRouter7, :get, "/first")
      assert conn.status == 200
      assert conn.resp_body == "users index"

      conn = call(Phoenix.Router.PipeThroughDeprecationTest.TestRouter7, :get, "/second")
      assert conn.status == 200
      assert conn.resp_body == "users show"
    end
  end
end
