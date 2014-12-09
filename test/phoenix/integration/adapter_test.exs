Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case
  use RouterHelper

  import ExUnit.CaptureIO
  alias Phoenix.Integration.AdapterTest.ProdEndpoint
  alias Phoenix.Integration.AdapterTest.DevEndpoint

  Application.put_env(:phoenix, ProdEndpoint, http: [port: "4807"])
  Application.put_env(:phoenix, DevEndpoint, http: [port: "4808"], debug_errors: true)

  for mod <- [ProdEndpoint, DevEndpoint] do
    defmodule mod do
      use Phoenix.Endpoint, otp_app: :phoenix

      plug :done

      def done(conn, _) do
        # Assert we never have a lingering sent message in the inbox
        refute_received {:plug_conn, :sent}

        case conn.path_info do
          [] -> halt resp conn, 200, "ok"
          _  -> raise "oops"
        end
      end
    end
  end

  @prod 4807
  @dev  4808

  alias Phoenix.Integration.HTTPClient

  test "adapters starts on configured port and serves requests and stops for prod" do
    capture_io fn -> ProdEndpoint.start end

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/unknown", %{})
      assert resp.status == 500
      assert resp.body == "500.html from Phoenix.ErrorView"
    end) =~ "** (RuntimeError) oops"

    ProdEndpoint.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
  end

  test "adapters starts on configured port and serves requests and stops for dev" do
    capture_io fn -> DevEndpoint.start end

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/unknown", %{})
      assert resp.status == 500
      assert resp.body =~ "RuntimeError at GET /"
    end) =~ "** (RuntimeError) oops"

    DevEndpoint.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
  end
end
