Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.EndpointTest do
  # This test case needs to be sync because we rely on
  # log capture which is global.
  use ExUnit.Case
  use RouterHelper

  import ExUnit.CaptureIO
  alias Phoenix.Integration.AdapterTest.ProdEndpoint
  alias Phoenix.Integration.AdapterTest.DevEndpoint

  @prod_config [http: [port: "4807"], url: [host: "example.com"]]
  Application.put_env(:endpoint_app, ProdEndpoint, @prod_config)
  @dev_config [http: [port: "4808"], debug_errors: true]
  Application.put_env(:endpoint_app, DevEndpoint, @dev_config)

  defmodule Router do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/" do
      send_resp conn, 200, "ok"
    end

    get "/router/oops" do
      _ = conn
      raise "oops"
    end

    match _ do
      raise Phoenix.Router.NoRouteError, conn: conn, router: __MODULE__
    end
  end

  for mod <- [ProdEndpoint, DevEndpoint] do
    defmodule mod do
      use Phoenix.Endpoint, otp_app: :endpoint_app

      plug :router, Router

      def call(conn, opts) do
        # Assert we never have a lingering sent message in the inbox
        refute_received {:plug_conn, :sent}

        if conn.path_info == ~w(oops) do
          raise "oops"
        end

        try do
          super(conn, opts)
        after
          # When we pipe downstream, downstream will always render,
          # either because the router is responding or because the
          # router error layer is kicking in.
          assert_received {:plug_conn, :sent}
          send self(), {:plug_conn, :sent}
        end
      end
    end
  end

  @prod 4807
  @dev  4808

  alias Phoenix.Integration.HTTPClient

  test "adapters starts on configured port and serves requests and stops for prod" do
    capture_io fn -> ProdEndpoint.start end

    # Configuration
    assert ProdEndpoint.config(:url) == [host: "example.com"]
    assert ProdEndpoint.url("/") == "http://example.com:4807/"

    config = put_in @prod_config[:url][:port], 1234
    assert ProdEndpoint.config_change([{ProdEndpoint, config}], []) == :ok
    assert ProdEndpoint.config(:url) == [host: "example.com", port: 1234]
    assert ProdEndpoint.url("/") == "http://example.com:1234/"

    # Requests
    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/unknown", %{})
    assert resp.status == 404
    assert resp.body == "404.html from Phoenix.ErrorView"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/oops", %{})
      assert resp.status == 500
      assert resp.body == "500.html from Phoenix.ErrorView"
    end) =~ "** (RuntimeError) oops"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/router/oops", %{})
      assert resp.status == 500
      assert resp.body == "500.html from Phoenix.ErrorView"
    end) =~ "** (RuntimeError) oops"

    ProdEndpoint.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
  end

  test "adapters starts on configured port and serves requests and stops for dev" do
    capture_io fn -> DevEndpoint.start end

    # Configuration
    assert DevEndpoint.config(:url) == [host: "localhost"]
    assert DevEndpoint.url("/") == "http://localhost:4808/"

    config = put_in @dev_config[:url], [port: 1234]
    assert DevEndpoint.config_change([{DevEndpoint, config}], []) == :ok
    assert DevEndpoint.config(:url) == [host: "localhost", port: 1234]
    assert DevEndpoint.url("/") == "http://localhost:1234/"

    # Requests
    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/unknown", %{})
    assert resp.status == 404
    assert resp.body =~ "NoRouteError at GET /unknown"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/oops", %{})
      assert resp.status == 500
      assert resp.body =~ "RuntimeError at GET /oops"
    end) =~ "** (RuntimeError) oops"

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/router/oops", %{})
      assert resp.status == 500
      assert resp.body =~ "RuntimeError at GET /router/oops"
    end) =~ "** (RuntimeError) oops"

    DevEndpoint.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
  end
end
