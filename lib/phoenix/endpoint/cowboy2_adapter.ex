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

    refs_and_specs =
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

    {refs, child_specs} = Enum.unzip(refs_and_specs)

    if drainer = refs != [] && Keyword.get(config, :drainer, []) do
      child_specs ++ [{Plug.Cowboy.Drainer, Keyword.put_new(drainer, :refs, refs)}]
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

  defp info(scheme, endpoint, ref) do
    server = "cowboy #{Application.spec(:cowboy)[:vsn]}"
    "Running #{inspect(endpoint)} with #{server} at #{bound_address(scheme, ref)}"
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
end
