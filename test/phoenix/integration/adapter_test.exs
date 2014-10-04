Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Integration.AdapterTest.Router
  alias Phoenix.Integration.AdapterTest.Controller
  alias Phoenix.Integration.HTTPClient

  @port 4807

  setup_all do
    Application.put_env(:phoenix, Router, port: @port)
    Router.start
    on_exit &Router.stop/0
    :ok
  end

  defmodule Router do
    use Phoenix.Router
    get "/", Controller, :index
  end

  defmodule Controller do
    use Phoenix.Controller

    plug :action
    def index(conn, _), do: text(conn, "ok")
  end

  test "adapters starts on configured port and serves requests, and stops" do
    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
    assert resp.status == 200
    assert resp.body == "ok"
    Router.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
  end
end
