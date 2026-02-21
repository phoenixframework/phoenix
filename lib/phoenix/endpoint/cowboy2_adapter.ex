defmodule Phoenix.Endpoint.Cowboy2Adapter do
  @moduledoc """
  The Cowboy2 adapter for Phoenix.

  ## Endpoint configuration

  This adapter uses the following endpoint configuration:

    * `:http` - the configuration for the HTTP server. It accepts all options
      as defined by [`Plug.Cowboy`](https://hexdocs.pm/plug_cowboy/). Defaults
      to `false`

    * `:https` - the configuration for the HTTPS server. It accepts all options
      as defined by [`Plug.Cowboy`](https://hexdocs.pm/plug_cowboy/). Defaults
      to `false`

    * `:http3` - the configuration for the HTTP/3 server. It starts a Cowboy
      QUIC listener with `:cowboy.start_quic/3`. Defaults to `false`

    * `:drainer` - a drainer process that triggers when your application is
      shutting down to wait for any on-going request to finish. It accepts all
      options as defined by [`Plug.Cowboy.Drainer`](https://hexdocs.pm/plug_cowboy/Plug.Cowboy.Drainer.html).
      Defaults to `[]`, which will start a drainer process for each configured endpoint,
      but can be disabled by setting it to `false`.

  ## Custom dispatch options

  You can provide custom dispatch options in order to use Phoenix's
  builtin Cowboy server with custom handlers. For example, to handle
  raw WebSockets [as shown in Cowboy's docs](https://github.com/ninenines/cowboy/tree/master/examples)).

  The options are passed to both `:http` and `:https` keys in the
  endpoint configuration. However, once you pass your custom dispatch
  options, you will need to manually wire the Phoenix endpoint by
  adding the following rule:

      {:_, Plug.Cowboy.Handler, {MyAppWeb.Endpoint, []}}

  For example:

      config :myapp, MyAppWeb.Endpoint,
        http: [dispatch: [
                {:_, [
                    {"/foo", MyAppWeb.CustomHandler, []},
                    {:_, Plug.Cowboy.Handler, {MyAppWeb.Endpoint, []}}
                  ]}]]

  It is also important to specify your handlers first, otherwise
  Phoenix will intercept the requests before they get to your handler.
  """

  require Logger

  @doc false
  def child_specs(endpoint, config) do
    otp_app = Keyword.fetch!(config, :otp_app)

    refs_and_specs_http =
      for {scheme, port} <- [http: 4000, https: 4040], opts = config[scheme] do
        port = :proplists.get_value(:port, opts, port)

        unless port do
          Logger.error(":port for #{scheme} config is nil, cannot start server")
          raise "aborting due to nil port"
        end

        # Ranch options are read from the top, so we keep the user opts first.
        opts = :proplists.delete(:port, opts) ++ [port: port_to_integer(port), otp_app: otp_app]
        child_spec(scheme, endpoint, opts, config[:code_reloader])
      end

    refs_and_specs =
      case config[:http3] do
        opts when is_list(opts) ->
          refs_and_specs_http ++ [http3_child_spec(endpoint, opts, config[:code_reloader])]

        _ ->
          refs_and_specs_http
      end

    {_refs, child_specs} = Enum.unzip(refs_and_specs)
    refs_for_drainer = Enum.map(refs_and_specs_http, &elem(&1, 0))

    drainer = refs_for_drainer != [] && Keyword.get(config, :drainer, [])

    if config[:http3] && drainer do
      Logger.warning(
        "HTTP/3 WebTransport sessions are not drained by Plug.Cowboy.Drainer; only Ranch listeners are drained"
      )
    end

    if drainer do
      child_specs ++ [{Plug.Cowboy.Drainer, Keyword.put_new(drainer, :refs, refs_for_drainer)}]
    else
      child_specs
    end
  end

  defp child_spec(scheme, endpoint, config, code_reloader?) do
    if scheme == :https do
      Application.ensure_all_started(:ssl)
    end

    ref = make_ref(endpoint, scheme)

    plug =
      if code_reloader? do
        {Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, []}}
      else
        {endpoint, []}
      end

    spec = Plug.Cowboy.child_spec(ref: ref, scheme: scheme, plug: plug, options: config)
    spec = update_in(spec.start, &{__MODULE__, :start_link, [scheme, endpoint, &1]})
    {ref, spec}
  end

  defp http3_child_spec(endpoint, config, code_reloader?) do
    port = Keyword.fetch!(config, :port)
    ref = make_ref(endpoint, :http3)

    socket_opts =
      [port: port_to_integer(port)]
      |> maybe_put_opt(:certfile, config)
      |> maybe_put_opt(:keyfile, config)
      |> Kernel.++(Keyword.get(config, :transport_options, []))

    transport_opts = %{socket_opts: socket_opts}

    plug =
      if code_reloader? do
        {Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, []}}
      else
        {endpoint, []}
      end

    dispatch =
      endpoint
      |> webtransport_routes()
      |> Kernel.++([{:_, Plug.Cowboy.Handler, plug}])
      |> then(fn routes -> :cowboy_router.compile([{:_, routes}]) end)

    proto_opts =
      config
      |> Keyword.drop([:port, :certfile, :keyfile, :transport_options])
      |> Enum.into(%{})
      |> Map.put_new(:enable_connect_protocol, true)
      |> Map.put_new(:h3_datagram, true)
      |> Map.put_new(:enable_webtransport, true)
      |> Map.put_new(:wt_max_sessions, 1)
      |> put_dispatch_env(dispatch)

    spec = %{
      id: ref,
      start: {__MODULE__, :start_http3, [endpoint, ref, transport_opts, proto_opts]},
      type: :worker
    }

    {ref, spec}
  end

  @doc false
  def start_link(scheme, endpoint, {m, f, [ref | _] = a}) do
    # ref is used by Ranch to identify its listeners, defaulting
    # to plug.HTTP and plug.HTTPS and overridable by users.
    case apply(m, f, a) do
      {:ok, pid} ->
        Logger.info(info(scheme, endpoint, ref))
        {:ok, pid}

      {:error, {:shutdown, {_, _, {:listen_error, _, :eaddrinuse}}}} = error ->
        Logger.error([info(scheme, endpoint, ref), " failed, port already in use"])
        error

      {:error, {:shutdown, {_, _, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
        Logger.error([info(scheme, endpoint, ref), " failed, port already in use"])
        error

      {:error, _} = error ->
        error
    end
  end

  @doc false
  def start_http3(endpoint, ref, transport_opts, proto_opts) do
    with :ok <- ensure_quic_available(endpoint, ref) do
      try do
        case :cowboy.start_quic(ref, transport_opts, proto_opts) do
          {:ok, listener_ref} ->
            Logger.info(info(:http3, endpoint, ref, transport_opts))
            start_http3_keeper(listener_ref)

          {:error, {:shutdown, {_, _, {:listen_error, _, :eaddrinuse}}}} = error ->
            Logger.error([
              info(:http3, endpoint, ref, transport_opts),
              " failed, port already in use"
            ])

            error

          {:error, {:shutdown, {_, _, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
            Logger.error([
              info(:http3, endpoint, ref, transport_opts),
              " failed, port already in use"
            ])

            error

          {:error, _} = error ->
            error
        end
      catch
        kind, reason ->
          Logger.error([
            info(:http3, endpoint, ref, transport_opts),
            " failed, QUIC startup prerequisites are not available: ",
            Exception.format_banner(kind, reason)
          ])

          {:error, {:shutdown, {kind, reason}}}
      end
    else
      {:error, _} = error ->
        error
    end
  end

  defp info(scheme, endpoint, ref) do
    server = "cowboy #{Application.spec(:cowboy)[:vsn]}"
    "Running #{inspect(endpoint)} with #{server} at #{bound_address(scheme, ref)}"
  end

  defp info(:http3, endpoint, _ref, transport_opts) do
    server = "cowboy #{Application.spec(:cowboy)[:vsn]}"
    "Running #{inspect(endpoint)} with #{server} at #{bound_http3_address(transport_opts)}"
  end

  defp info(scheme, endpoint, ref, _transport_opts), do: info(scheme, endpoint, ref)

  defp start_http3_keeper(listener_ref) do
    Task.start_link(fn ->
      Process.flag(:trap_exit, true)

      receive do
        {:EXIT, _from, _reason} -> :ok
      end

      if Code.ensure_loaded?(:quicer) and function_exported?(:quicer, :close_listener, 1) do
        _ = apply(:quicer, :close_listener, [listener_ref])
      end

      :ok
    end)
  end

  defp bound_address(scheme, ref) do
    case :ranch.get_addr(ref) do
      {:local, unix_path} ->
        "#{unix_path} (#{scheme}+unix)"

      {addr, port} ->
        "#{:inet.ntoa(addr)}:#{port} (#{scheme})"
    end
  rescue
    _ -> scheme
  end

  # TODO: Remove this once {:system, env_var} deprecation is removed
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  def server_info(endpoint, :http3) do
    opts = endpoint.config(:http3, [])

    with {:ok, port} <- Keyword.fetch(opts, :port) do
      {:ok, {Keyword.get(opts, :ip, {0, 0, 0, 0}), port_to_integer(port)}}
    else
      :error -> {:error, :not_found}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def server_info(endpoint, scheme) do
    address =
      endpoint
      |> make_ref(scheme)
      |> :ranch.get_addr()

    {:ok, address}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp make_ref(endpoint, scheme) do
    Module.concat(endpoint, scheme |> Atom.to_string() |> String.upcase())
  end

  defp webtransport_routes(endpoint) do
    if function_exported?(endpoint, :__webtransport_routes__, 0) do
      endpoint.__webtransport_routes__()
    else
      []
    end
  end

  defp maybe_put_opt(opts, key, config) do
    case Keyword.fetch(config, key) do
      {:ok, value} -> Keyword.put(opts, key, value)
      :error -> opts
    end
  end

  defp put_dispatch_env(proto_opts, dispatch) do
    env =
      case Map.get(proto_opts, :env) do
        nil -> %{dispatch: dispatch}
        env when is_map(env) -> Map.put(env, :dispatch, dispatch)
        env when is_list(env) -> env |> Enum.into(%{}) |> Map.put(:dispatch, dispatch)
        _ -> %{dispatch: dispatch}
      end

    Map.put(proto_opts, :env, env)
  end

  defp bound_http3_address(transport_opts) do
    socket_opts = Map.get(transport_opts, :socket_opts, [])
    port = Keyword.get(socket_opts, :port, :unknown)

    case Keyword.get(socket_opts, :ip, {0, 0, 0, 0}) do
      {:local, unix_path} ->
        "#{unix_path} (http3+unix)"

      addr when is_tuple(addr) ->
        "#{:inet.ntoa(addr)}:#{port} (http3)"

      addr when is_binary(addr) ->
        "#{addr}:#{port} (http3)"

      _ ->
        "#{port} (http3)"
    end
  end

  defp ensure_quic_available(endpoint, ref) do
    case Application.ensure_all_started(:quicer) do
      {:ok, _} ->
        :ok

      {:error, reason} = error ->
        Logger.error([
          info(:http3, endpoint, ref),
          " failed, quicer dependency is unavailable: ",
          inspect(reason)
        ])

        error
    end
  end
end
