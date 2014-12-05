Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case
  use ConnHelper

  import ExUnit.CaptureIO

  Application.put_env(:phoenix, __MODULE__.ProdRouter, http: [port: "4807"])

  defmodule ProdRouter do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(conn, _) do
      # Assert we never have a lingering sent message in the inbox
      refute_received {:plug_conn, :sent}

      case conn.path_info do
        [] -> halt resp conn, 200, "ok"
        _  -> raise "oops"
      end
    end
  end

  Application.put_env(:phoenix, __MODULE__.DevRouter, http: [port: "4808"], debug_errors: true)

  defmodule DevRouter do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(conn, _) do
      # Assert we never have a lingering @already_sent entry in the inbox
      refute_received {:plug_conn, :sent}

      case conn.path_info do
        [] -> halt resp conn, 200, "ok"
        _  -> raise "oops"
      end
    end
  end

  @prod 4807
  @dev  4808

  alias Phoenix.Integration.HTTPClient

  test "adapters starts on configured port and serves requests and stops for prod" do
    capture_io fn -> ProdRouter.start end

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/unknown", %{})
      assert resp.status == 500
      assert resp.body == "500.html from Phoenix.ErrorView"
    end) =~ "** (RuntimeError) oops"

    ProdRouter.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
  end

  test "adapters starts on configured port and serves requests and stops for dev" do
    capture_io fn -> DevRouter.start end

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/unknown", %{})
      assert resp.status == 500
      assert resp.body =~ "RuntimeError at GET /"
    end) =~ "** (RuntimeError) oops"

    DevRouter.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
  end
end
