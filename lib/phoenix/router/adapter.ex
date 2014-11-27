defmodule Phoenix.Router.Adapter do
  # This module contains the logic for starting and stopping
  # the router server. Today, much of the logic is specific
  # to cowboy but we can make it more generic when we add
  # support for other adapters.
  @moduledoc false

  import Plug.Conn, only: [put_private: 3, put_status: 2]
  import Phoenix.Controller, only: [router_module: 1]

  @unsent [:unset, :set]

  @doc """
  The router configuration used at compile time.
  """
  def config(router) do
    config = Application.get_env(:phoenix, router, [])

    otp_app = cond do
      config[:otp_app] ->
        config[:otp_app]
      Code.ensure_loaded?(Mix.Project) && Mix.Project.config[:app] ->
        Mix.Project.config[:app]
      true ->
        raise "please set :otp_app config for #{inspect router}"
    end

    Phoenix.Config.merge(defaults(otp_app), config)
  end

  @doc """
  Starts the router.
  """
  def start(otp_app, module) do
    Phoenix.Config.start_supervised(module, defaults(otp_app))

    # TODO: We need to test this logic when we support custom adapters.
    if config = module.config(:http) do
      config =
        config
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4000)
      start(:http, otp_app, module, config)
    end

    if config = module.config(:https) do
      config =
        Keyword.merge(module.config(:http) || [], module.config(:https))
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4040)
      start(:https, otp_app, module, config)
    end

    :ok
  end

  defp start(scheme, otp_app, module, config) do
    opts = dispatch(otp_app, module, config)
    report apply(Plug.Adapters.Cowboy, scheme, [module, [], opts]), scheme, module, opts
  end

  defp dispatch(_otp_app, module, config) do
    dispatch = module.__transport__ ++
               [{:_, Phoenix.Router.CowboyHandler, {module, []}}]

    config
    |> Keyword.put(:dispatch, [{:_, dispatch}])
    |> Keyword.put(:port, to_integer(config[:port]))
  end

  defp to_integer(binary) when is_binary(binary), do: String.to_integer(binary)
  defp to_integer(integer) when is_integer(integer), do: integer

  defp report(result, scheme, module, opts) do
    case result do
      {:ok, pid} ->
        [:green, "Running #{inspect module} with Cowboy on port #{inspect opts[:port]} (#{scheme})"]
        |> IO.ANSI.format
        |> IO.puts
        {:ok, pid}

      {:error, :eaddrinuse} ->
        raise "Port #{inspect opts[:port]} is already in use"

      {:error, reason} ->
        raise "Something went wrong while starting router: #{Exception.format_exit reason}"
    end
  end

  @doc """
  Stops the router.
  """
  def stop(_otp_app, module) do
    if module.config(:http) do
      Plug.Adapters.Cowboy.shutdown(Module.concat(module, HTTP))
    end

    if module.config(:https) do
      Plug.Adapters.Cowboy.shutdown(Module.concat(module, HTTPS))
    end

    Phoenix.Config.stop(module)
    :ok
  end

  defp defaults(otp_app) do
    [otp_app: otp_app,

     # Compile-time config
     parsers: [parsers: [:urlencoded, :multipart, :json],
               pass: ["*/*"], json_decoder: Poison],
     static: [at: "/"],
     session: false,

     # Transports
     transports: [longpoller: [window_ms: 10_000]],

     # Runtime config
     url: [host: "localhost"],
     http: false,
     https: false,
     secret_key_base: nil,
     catch_errors: true,
     debug_errors: false,
     error_controller: Phoenix.Controller.ErrorController]
  end

  # TODO: Move the dispatch logic and error handling elsewhere.

  @doc """
  Carries out `Phoenix.Controller` dispatch for router match
  """
  def dispatch(conn, router) do
    conn.private.phoenix_route.(conn)
  end

  defp handle_err(conn, kind, error, true) do
    conn
    |> put_private(:phoenix_error, {kind, error})
    |> put_status(500)
  end

  defp handle_err(_, kind, err, _nocatch), do:
    :erlang.raise(kind, err, System.stacktrace)

  # Handles sending 404 response based on Router's Mix Config settings
  #
  # ## Router Configuration Options
  #
  #   * error_controller - The optional Module to have `not_found/2` action invoked
  #                       when 404's status occurs.
  #                       Default `Phoenix.Controller.ErrorController`
  #   * debug_errors - Bool to display Phoenix's route debug page for 404 status.
  #                    Default `false`
  defp after_dispatch(conn = %Plug.Conn{state: state, status: status})
      when state in @unsent and status == 404 do
    conn   = put_in conn.halted, false
    router = router_module(conn)

    if router.config(:debug_errors) do
      Phoenix.Controller.ErrorController.call(conn, :not_found_debug)
    else
      router.config(:error_controller).call(conn, :not_found)
    end
  end

  # Handles sending 500 response based on Router's Mix Config settings
  #
  # ## Router Configuration Options
  #
  #   * error_controller - The optional Module to have `error/2` action invoked
  #                       when 500's status occurs.
  #                       Default `Phoenix.Controller.ErrorController`
  #   * catch_errors - Bool to catch errors at the Router level. Default `true`
  #   * debug_errors - Bool to display Phoenix's route debug page for 500 status.
  #                    Default `false`
  #
  defp after_dispatch(conn = %Plug.Conn{state: state, status: status})
      when state in @unsent and status == 500 do
    conn   = put_in conn.halted, false
    router = router_module(conn)

    if router.config(:debug_errors) do
      Phoenix.Controller.ErrorController.call(conn, :error_debug)
    else
      router.config(:error_controller).call(conn, :error)
    end
  end
  defp after_dispatch(conn), do: conn
end
