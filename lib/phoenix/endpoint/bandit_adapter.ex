defmodule Phoenix.Endpoint.BanditAdapter do
  @moduledoc """
  A Bandit adapter for Phoenix.

  Note that this adapter does not currently support WebSocket connections; it is
  only suitable for use with HTTP(S)-only Phoenix instances.

  To use this adapter, your project will need to include Bandit as a dependency; see
  https://hex.pm/bandit for details on the currently supported version of Bandit to include.

  ## Endpoint configuration

  This adapter uses the following endpoint configuration:

    * `:http`: the configuration for the HTTP server. Accepts the following options:
      * `port`: The port to run on. Defaults to 4000
      * `ip`: The address to bind to. Can be specified as `{127, 0, 0, 1}`, or using `{:local,
        path}` to bind to a Unix domain socket. Defaults to {127, 0, 0, 1}.
      * `transport_options`: Any valid value from `ThousandIsland.Transports.TCP`
    
      Defaults to `false`, which will cause Bandit to not start an HTTP server.

    * `:https`: the configuration for the HTTPS server. Accepts the following options:
      * `port`: The port to run on. Defaults to 4040
      * `ip`: The address to bind to. Can be specified as `{127, 0, 0, 1}`, or using `{:local,
        path}` to bind to a Unix domain socket. Defaults to {127, 0, 0, 1}.
      * `transport_options`: Any valid value from `ThousandIsland.Transports.SSL`
    
      Defaults to `false`, which will cause Bandit to not start an HTTPS server.
  """

  require Logger

  @doc false
  def child_specs(endpoint, config) do
    for {scheme, port} <- [http: 4000, https: 4040], opts = config[scheme] do
      port = :proplists.get_value(:port, opts, port)

      unless port do
        Logger.error(":port for #{scheme} config is nil, cannot start server")
        raise "aborting due to nil port"
      end

      ip = :proplists.get_value(:ip, opts, {127, 0, 0, 1})
      transport_options = :proplists.get_value(:transport_options, opts, [])
      opts = [port: port_to_integer(port), transport_options: [ip: ip] ++ transport_options]

      [plug: endpoint, scheme: scheme, options: opts]
      |> Bandit.child_spec()
      |> Supervisor.child_spec(id: {endpoint, scheme})
    end
  end

  # TODO: Deprecate {:system, env_var} once we require Elixir v1.9+
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port
end
