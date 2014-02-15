defmodule Phoenix.Router.ControllerTest do
  use ExUnit.Case
  use PlugHelper

  defmodule RedirController do
    use Phoenix.Controller
    def redir_301(conn) do
      redirect conn, 301, "/users"
    end
    def redir_302(conn) do
      redirect conn, "/users"
    end
  end

  defmodule Router do
    use Phoenix.Router
    get "/users/not_found_301", RedirController, :redir_301
    get "/users/not_found_302", RedirController, :redir_302
  end

  test "redirect without status performs 302 redirect do url" do
    conn = simulate_request(Router, :get, "users/not_found_302")
    assert conn.status == 302
  end

  test "redirect without status performs 301 redirect do url" do
    conn = simulate_request(Router, :get, "users/not_found_301")
    assert conn.status == 301
  end
end
