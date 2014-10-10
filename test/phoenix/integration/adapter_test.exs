Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Phoenix.Integration.HTTPClient

  defmodule Router do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(conn, _) do
      send_resp conn, 200, "ok"
    end
  end

  @port 4807

  setup_all do
    Application.put_env(:phoenix, Router, http: [port: "4807"], https: false)
    capture_io fn -> Router.start end
    :ok
  end

  test "adapters starts on configured port and serves requests, and stops" do
    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
    assert resp.status == 200
    assert resp.body == "ok"
    Router.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@port}", %{})
  end
end
