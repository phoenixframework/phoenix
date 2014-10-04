defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Integration.AdapterTest.Router
  alias Phoenix.Integration.AdapterTest.Controller

  Application.put_env(:phoenix, Router, port: 4807)

  def resp(response) do
    {:ok, {{_, status, _}, _, body}} = response
    %{status: status, body: body}
  end

  setup_all do
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

  test "adapters starts on configured port and serves requests" do
    resp = resp(:httpc.request(:get, {'http://127.0.0.1:4807', []}, [],
                               body_format: :binary))
    assert resp.status == 200
    assert resp.body == "ok"
  end
end
