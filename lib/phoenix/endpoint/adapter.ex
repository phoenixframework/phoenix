defmodule Phoenix.Endpoint.Adapter do
  # This module contains the logic used by most functions
  # in Phoenix.Endpoint as well the supervisor for starting
  # the adapters/handlers.
  @moduledoc false

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, mod) do
    import Supervisor.Spec
    conf       = config(otp_app, mod)
    pub_conf   = conf[:pubsub]
    asset_conf = conf[:assets]

    asset_children = []
    pubsub_children = case pub_conf[:adapter] do
      nil     -> []
      adapter ->
        [supervisor(adapter, [mod.__pubsub_server__(), pub_conf[:options] || []])]
    end

    if asset_conf[:build] do
      asset_children = asset_children ++ [worker(Task, [fn ->
        System.cmd(
          Path.expand("node_modules/brunch/bin/brunch"), ["watch"],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )
      end])]
    end
    asset_children = case asset_conf[:live_reload] do
      []    -> asset_children
      paths ->
        asset_children ++ [
          worker(Phoenix.CodeReloader.Watcher, [paths, {__MODULE__, :assets_change, [mod]}])
        ]
    end

    children = asset_children ++ pubsub_children ++ [
      worker(Phoenix.Config, [otp_app, mod, defaults(otp_app, mod)]),
      supervisor(Phoenix.Endpoint.Server, [otp_app, mod]),
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: mod)
  end

  def assets_change(endpoint) do
    endpoint.broadcast!("phoenix", "assets:change", %{})
  end

  @doc """
  The endpoint configuration used at compile time.
  """
  def config(otp_app, endpoint) do
    Phoenix.Config.from_env(otp_app, endpoint, defaults(otp_app, endpoint))
  end

  defp defaults(otp_app, module) do
    [otp_app: otp_app,

     # Compile-time config
     debug_errors: false,
     render_errors: render_errors(module),

     # Transports
     transports: [
       longpoller_window_ms: 10_000,
       longpoller_pubsub_timeout_ms: 1000,
       longpoller_crypto: [iterations: 1000,
                           length: 32,
                           digest: :sha256,
                           cache: Plug.Keys],

       websocket_serializer: Phoenix.Transports.JSONSerializer,
       websocket_timeout: :infinity
     ],

     # Runtime config
     cache_static_lookup: false,
     http: false,
     https: false,
     reloadable_paths: ["web"],
     secret_key_base: nil,
     server: Application.get_env(:phoenix, :serve_endpoints, false),
     url: [host: "localhost"],
     pubsub: [],

     # Assets
     assets: [
       build: false,
       live_reload: []
     ]]
  end

  defp render_errors(module) do
    module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("ErrorView")
  end

  @doc """
  Builds the endpoint url from its configuration.

  The result is wrapped in a `{:cache, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def url(endpoint) do
    {scheme, port} =
      cond do
        config = endpoint.config(:https) ->
          {"https", config[:port]}
        config = endpoint.config(:http) ->
          {"http", config[:port]}
        true ->
          {"http", "80"}
      end

    url    = endpoint.config(:url)
    scheme = url[:scheme] || scheme
    host   = url[:host]
    port   = port_to_string(url[:port] || port)

    {:cache,
      case {scheme, port} do
        {"https", "443"} -> "https://" <> host
        {"http", "80"}   -> "http://" <> host
        {_, _}           -> scheme <> "://" <> host <> ":" <> port
      end}
  end

  @doc """
  Returns the static path of a file in the static root directory.

  When file exists, it includes a timestamp. When it doesn't exist,
  just the static path is returned.

  The result is wrapped in a `{:cache | :stale, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def static_path(endpoint, "/" <> _ = path) do
    file = Application.app_dir(endpoint.config(:otp_app), Path.join("priv/static", path))

    case File.stat(file) do
      {:ok, %File.Stat{type: :regular, mtime: mtime, size: size}} ->
        key = if endpoint.config(:cache_static_lookup), do: :cache, else: :stale
        vsn = {size, mtime} |> :erlang.phash2() |> Integer.to_string(16)
        {key, path <> "?vsn=" <> vsn}
      _ ->
        {:stale, path}
    end
  end

  def static_path(_endpoint, path) when is_binary(path) do
    raise ArgumentError, "static_path/2 expects a path starting with / as argument"
  end

  defp port_to_string({:system, env_var}), do: System.get_env(env_var)
  defp port_to_string(port), do: to_string(port)
end
