defmodule Phoenix.Router.Adapter do
  # This module contains the logic for starting and stopping
  # the router server. Today, much of the logic is specific
  # to cowboy but we can make it more generic when we add
  # support for other adapters.
  @moduledoc false

  import Plug.Conn, only: [put_private: 3, put_status: 2]
  import Phoenix.Controller.Connection, only: [assign_error: 3, router_module: 1]

  @unsent [:unset, :set]
  alias Phoenix.Config

  @doc """
  Starts the router.
  """
  def start(otp_app, module, dispatch_opts, opts) do
    Phoenix.Config.supervise(otp_app, module)

    if Keyword.get(opts, :http, true) &&
       (config = module.config(:http)) do
      run(:http, module, config, dispatch_opts)
    end

    if Keyword.get(opts, :https, true) &&
       (config = module.config(:https)) do
      config =
        (module.config(:http) || [])
        |> Keyword.delete(:port)
        |> Keyword.merge(module.config(:https))
      run(:https, module, config, dispatch_opts)
    end
  end

  defp run(scheme, module, config, dispatch_opts) do
    opts = dispatch(module, config, dispatch_opts)
    report apply(Plug.Adapters.Cowboy, scheme, [module, [], opts]), scheme, module, opts
  end

  defp dispatch(module, config, dispatch_opts) do
    dispatch = dispatch_opts ++
               [{:_, Plug.Adapters.Cowboy.Handler, {module, []}}]
    IO.inspect dispatch
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
        raise "Something went wrong while starting router: #{inspect reason}"
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
    IO.puts "#{module} has been stopped"
  end

  # TODO: Move the dispatch logic and error handling elsewhere.

  @doc """
  Carries out Controller dispatch for router match
  """
  def dispatch(conn, router) do
    try do
      conn.private.phoenix_route.(conn)
    catch
      kind, err ->
        handle_err(conn, kind, err, Phoenix.Config.router(router, [:catch_errors]))
    end
    |> after_dispatch
  end

  defp handle_err(conn, kind, error, true) do
    conn
    |> assign_error(kind, error)
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

    if Config.router(router, [:debug_errors]) do
      Phoenix.Controller.ErrorController.call(conn, :not_found_debug)
    else
      Config.router!(router, [:error_controller]).call(conn, :not_found)
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

    if Config.router(router, [:debug_errors]) do
      Phoenix.Controller.ErrorController.call(conn, :error_debug)
    else
      Config.router!(router, [:error_controller]).call(conn, :error)
    end
  end
  defp after_dispatch(conn), do: conn
end
