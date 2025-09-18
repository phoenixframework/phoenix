Code.require_file "../../support/http_client.exs", __DIR__
Code.require_file "../../support/endpoint_helper.exs", __DIR__

defmodule Phoenix.Integration.EndpointTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  import Phoenix.Integration.EndpointHelper

  alias Phoenix.Integration.AdapterTest.ProdEndpoint
  alias Phoenix.Integration.AdapterTest.DevEndpoint
  alias Phoenix.Integration.AdapterTest.ProdInet6Endpoint

  # Find available ports to use for this test
  [dev, prod, prod_inet6] = get_unused_port_numbers(3)
  @dev dev
  @prod prod
  @prod_inet6 prod_inet6

  Application.put_env(:endpoint_int, ProdEndpoint,
    http: [port: @prod], url: [host: "example.com"], server: true, drainer: false,
    render_errors: [accepts: ~w(html json)])
  Application.put_env(:endpoint_int, DevEndpoint,
    http: [port: @dev], debug_errors: true, drainer: false)

  Application.put_env(:endpoint_int, ProdInet6Endpoint,
    http: [port: @prod_inet6, transport_options: [socket_opts: [:inet6]]],
    url: [host: "example.com"],
    server: true)

  defmodule Router do
    @moduledoc """
    Let's use a plug router to test this endpoint.
    """
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

    def __routes__ do
      []
    end
  end

  defmodule Wrapper do
    @moduledoc """
    A wrapper around the endpoint call to extract information.

    This exists so we can verify that the exception handling
    in the Phoenix endpoint is working as expected. In order
    to do that, we need to wrap the endpoint.call/2 in a
    before compile callback so it wraps the whole stack,
    including render errors and debug errors functionality.
    """

    defmacro __before_compile__(_) do
      quote do
        defoverridable [call: 2]

        def call(conn, opts) do
          # Assert we never have a lingering sent message in the inbox
          refute_received {:plug_conn, :sent}

          try do
            super(conn, opts)
          after
            # When we pipe downstream, downstream will always render,
            # either because the router is responding or because the
            # endpoint error layer is kicking in.
            assert_received {:plug_conn, :sent}
            send self(), {:plug_conn, :sent}
          end
        end
      end
    end
  end

  for mod <- [ProdEndpoint, DevEndpoint, ProdInet6Endpoint] do
    defmodule mod do
      use Phoenix.Endpoint, otp_app: :endpoint_int
      @before_compile Wrapper

      plug :oops
      plug Router

      @doc """
      Verify errors from the plug stack too (before the router).
      """
      def oops(conn, _opts) do
        if conn.path_info == ~w(oops) do
          raise "oops"
        else
          conn
        end
      end
    end
  end

  alias Phoenix.Integration.HTTPClient

  test "starts drainer in supervision tree if configured" do
    capture_log fn ->
      {:ok, _} = ProdInet6Endpoint.start_link()
      assert List.keyfind(Supervisor.which_children(ProdInet6Endpoint), Plug.Cowboy.Drainer, 0)
      Supervisor.stop(ProdInet6Endpoint)

      {:ok, _} = ProdEndpoint.start_link()
      refute List.keyfind(Supervisor.which_children(ProdEndpoint), Plug.Cowboy.Drainer, 0)
      Supervisor.stop(ProdEndpoint)
    end
  end

  test "adapters starts on configured port and serves requests and stops for prod" do
    capture_log fn ->
      # Has server: true
      {:ok, _} = ProdEndpoint.start_link()

      # Requests
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
      assert resp.status == 200
      assert resp.body == "ok"

      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/unknown", %{})
      assert resp.status == 404
      assert resp.body == "404.html from Phoenix.ErrorView"

      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/unknown?_format=json", %{})
      assert resp.status == 404
      assert resp.body |> Phoenix.json_library().decode!() == %{"error" => "Got 404 from error with GET"}

      capture_log(fn ->
        {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/oops", %{})
        assert resp.status == 500
        assert resp.body == "500.html from Phoenix.ErrorView"

        {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}/router/oops", %{})
        assert resp.status == 500
        assert resp.body == "500.html from Phoenix.ErrorView"

        Supervisor.stop(ProdEndpoint)
      end)

      {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
    end
  end

  test "adapters starts on configured port and serves requests and stops for dev" do
    # Toggle globally
    serve_endpoints(true)
    on_exit(fn -> serve_endpoints(false) end)

    capture_log fn ->
      # Has server: false
      {:ok, _} = DevEndpoint.start_link()

      # Requests
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
      assert resp.status == 200
      assert resp.body == "ok"

      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/unknown", %{})
      assert resp.status == 404
      assert resp.body =~ "NoRouteError at GET /unknown"

      capture_log(fn ->
        {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/oops", %{})
        assert resp.status == 500
        assert resp.body =~ "RuntimeError at GET /oops"

        {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}/router/oops", %{})
        assert resp.status == 500
        assert resp.body =~ "RuntimeError at GET /router/oops"

        Supervisor.stop(DevEndpoint)
      end)

      {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
    end
  end

  test "adapters starts on configured port and inet6 for prod" do
    capture_log fn ->
      # Has server: true
      {:ok, _} = ProdInet6Endpoint.start_link()

      Supervisor.stop(ProdInet6Endpoint)
    end
  end

  defp serve_endpoints(bool) do
    Application.put_env(:phoenix, :serve_endpoints, bool)
  end
end
