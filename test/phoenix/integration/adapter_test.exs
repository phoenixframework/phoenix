Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Phoenix.Integration.AdapterTest.Router
  alias Phoenix.Integration.HTTPClient

  @port 4807
  Application.put_env(:phoenix, Router, http: [port: "4807"], https: false)

  defmodule Router do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(conn, _) do
      send_resp conn, 200, "ok"
    end
  end

  setup_all do
    capture_io fn -> Router.start end
    on_exit fn -> capture_io &Router.stop/0 end
    :ok
  end

  test "adapters starts on configured port and serves requests, and stops" do
    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
    assert resp.status == 200
    assert resp.body == "ok"
    capture_io fn -> Router.stop end
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
  end
end
