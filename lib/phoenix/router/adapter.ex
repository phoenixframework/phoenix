defmodule Phoenix.Router.Adapter do
  # TODO: This is a temporary module that we need to better handle.
  # * The exception handling can be moved elsewhere.
  # * The adapter stuff can be moved directly to the adapter module.
  @moduledoc false

  import Plug.Conn, only: [put_private: 3]
  import Phoenix.Controller.Connection, only: [assign_status: 2, assign_error: 3]

  @unsent [:unset, :set]

  @doc """
  Starts the Router module with provided List of options
  """
  def start(module, opts) do
    protocol = if opts[:ssl], do: :https, else: :http
    case apply(Plug.Adapters.Cowboy, protocol, [module, [], opts]) do
      {:ok, pid} ->
        [:green, "Running #{Phoenix.Naming.module_name(module)} with Cowboy on port #{inspect opts[:port]}"]
        |> IO.ANSI.format
        |> IO.puts
        {:ok, pid}

      {:error, :eaddrinuse} ->
        raise "Port #{inspect opts[:port]} is already in use"
    end
  end

  @doc """
  Stops the Router module with provided List of options
  """
  def stop(module, opts) do
    protocol = if opts[:ssl], do: HTTPS, else: HTTP
    apply(Plug.Adapters.Cowboy, :shutdown, [Module.concat(module, protocol)])
    IO.puts "#{module} has been stopped"
  end

  @doc """
  Merges Plug options with dispatch options, delegating to adapter module for
  adapter specific option handling

    * options - The Plug routing options, ie, [port: 4000, ip: {127, 0, 0, 1}]
    * dispatch_options - The adapter dispatch_options built from `dispatch_option` macro
    * adapter - The webserver adapter module to handle adapter spefic options, ie `Adapters.Cowboy`

  """
  def merge(options, dispatch_options, router_module, adapter) do
    Phoenix.Config.router(router_module)
    |> map_config
    |> Dict.merge(options)
    |> adapter.merge_options(dispatch_options, router_module)
  end

  defp map_config([]), do: []
  defp map_config([{k, v}|t]), do: [option(k,v)] ++ map_config(t)

  defp option(:port, val), do: { :port, convert(:int, val) }
  defp option(:proxy_port, val), do: { :proxy_port, convert(:int, val) }
  defp option(key, val), do: { key, val }

  defp convert(:int, val) when is_integer(val), do: val
  defp convert(:int, val), do: String.to_integer(val)

  @doc """
  Carries out Controller dispatch for router match
  """
  def dispatch(conn, router) do
    conn = put_private(conn, :phoenix_router, router)
    try do
      router.match(conn, conn.method, conn.path_info)
    catch
      kind, err ->
        handle_err(conn, kind, err, Phoenix.Config.router(router, [:catch_errors]))
    end
    |> after_dispatch
  end

  defp handle_err(conn, kind, error, _catch_errors = true) do
    conn
    |> assign_error(kind, error)
    |> assign_status(500)
  end
  defp handle_err(_, :throw, err, _nocatch), do: throw(err)
  defp handle_err(_, :error, err, _nocatch), do: reraise(err, System.stacktrace)

  defp after_dispatch(conn = %Plug.Conn{state: state, status: status})
      when state in @unsent and status == 404 do
    Phoenix.Controller.Action.handle_not_found(conn)
  end
  defp after_dispatch(conn = %Plug.Conn{state: state, status: status})
      when state in @unsent and status == 500 do
    Phoenix.Controller.Action.handle_error(conn)
  end
  defp after_dispatch(conn), do: conn
end
