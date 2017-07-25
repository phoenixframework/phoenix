defmodule Phoenix.Endpoint.Supervisor do
  # This module contains the logic used by most functions
  # in Phoenix.Endpoint as well the supervisor for starting
  # the adapters/handlers.
  @moduledoc false

  require Logger
  use Supervisor

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, mod) do
    case Supervisor.start_link(__MODULE__, {otp_app, mod}, name: mod) do
      {:ok, _} = ok ->
        warmup(mod)
        ok
      {:error, _} = error ->
        error
    end
  end

  @doc false
  # TODO: Ideally every process would be named based on a `name` option
  # instead of using the module. However, __phoenix_pubsub__ is highly
  # dependent on the module name, so we should consider enabling this
  # once we move to Firenest.
  def init({otp_app, mod}) do
    id = :crypto.strong_rand_bytes(16) |> Base.encode64

    conf =
      case mod.init(:supervisor, [endpoint_id: id] ++ config(otp_app, mod)) do
        {:ok, conf} -> conf
        other -> raise ArgumentError, "expected init/2 callback to return {:ok, config}, got: #{inspect other}"
      end

    # TODO: Remove as soon as v1.3 is out
    if conf[:on_init] do
      Logger.warn """
      The :on_init configuration in #{inspect mod} introduced in Phoenix v1.3.0-rc
      is no longer supported and won't be invoked. Instead, use the init/2 callback,
      which is always called. In your config/prod.exs, instead of :on_init, set:

          load_from_system_env: true

      and then in #{inspect mod}:

          def init(_key, config) do
            if config[:load_from_system_env] do
              port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
              {:ok, Keyword.put(config, :http, [:inet6, port: port])}
            else
              {:ok, config}
            end
          end
      """
    end

    server? = server?(conf)

    if server? and conf[:code_reloader] do
      Phoenix.CodeReloader.Server.check_symlinks()
    end

    children =
      pubsub_children(mod, conf) ++
      config_children(mod, conf, otp_app) ++
      server_children(mod, conf, server?) ++
      watcher_children(mod, conf, server?)

    supervise(children, strategy: :one_for_one)
  end

  defp config_children(mod, conf, otp_app) do
    args = [mod, conf, defaults(otp_app, mod), [name: Module.concat(mod, "Config")]]
    [worker(Phoenix.Config, args)]
  end

  defp pubsub_children(mod, conf) do
    pub_conf = conf[:pubsub]

    if adapter = pub_conf[:adapter] do
      pub_conf = [fastlane: Phoenix.Channel.Server] ++ pub_conf
      [supervisor(adapter, [mod.__pubsub_server__(), pub_conf])]
    else
      []
    end
  end

  # TODO: Handlers -> Phoenix.Server
  # TODO: Each transport should have its own tree
  defp server_children(mod, conf, server?) do
    if server? do
      server = Module.concat(mod, "Server")
      long_poll = Module.concat(mod, "LongPoll.Supervisor")
      [supervisor(Phoenix.Endpoint.Handler, [conf[:otp_app], mod, [name: server]]),
       supervisor(Phoenix.Transports.LongPoll.Supervisor, [[name: long_poll]])]
    else
      []
    end
  end

  defp watcher_children(_mod, conf, server?) do
    if server? do
      Enum.map(conf[:watchers], fn {cmd, args} ->
        worker(Phoenix.Endpoint.Watcher, watcher_args(cmd, args),
               id: {cmd, args}, restart: :transient)
      end)
    else
      []
    end
  end
  defp watcher_args(cmd, cmd_args) do
    {args, opts} = Enum.split_while(cmd_args, &is_binary(&1))
    [cmd, args, opts]
  end

  @doc """
  The endpoint configuration used at compile time.
  """
  def config(otp_app, endpoint) do
    Phoenix.Config.from_env(otp_app, endpoint, defaults(otp_app, endpoint))
  end

  @doc """
  Checks if Endpoint's web server has been configured to start.
  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    otp_app
    |> config(endpoint)
    |> server?()
  end
  def server?(conf) when is_list(conf) do
    Keyword.get(conf, :server, Application.get_env(:phoenix, :serve_endpoints, false))
  end

  defp defaults(otp_app, module) do
    [otp_app: otp_app,
     handler: Phoenix.Endpoint.CowboyHandler,

     # Compile-time config
     code_reloader: false,
     debug_errors: false,
     render_errors: [view: render_errors(module), accepts: ~w(html), layout: false],

     # Runtime config
     cache_static_manifest: nil,
     check_origin: true,
     http: false,
     https: false,
     reloadable_compilers: [:gettext, :phoenix, :elixir],
     secret_key_base: nil,
     static_url: nil,
     url: [host: "localhost", path: "/"],

     # Supervisor config
     pubsub: [pool_size: 1],
     watchers: []]
  end

  defp render_errors(module) do
    module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("ErrorView")
  end

  @doc """
  Callback that changes the configuration from the app callback.
  """
  def config_change(endpoint, changed, removed) do
    res = Phoenix.Config.config_change(endpoint, changed, removed)
    warmup(endpoint)
    res
  end

  @doc """
  Builds the endpoint url from its configuration.

  The result is wrapped in a `{:cache, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def url(endpoint) do
    {:cache, build_url(endpoint, endpoint.config(:url)) |> String.Chars.URI.to_string()}
  end

  @doc """
  Builds the host for caching.
  """
  def host(endpoint) do
    {:cache, host_to_binary(endpoint.config(:url)[:host] || "localhost")}
  end

  @doc """
  Builds the path for caching.
  """
  def path(endpoint) do
    {:cache, empty_string_if_root(endpoint.config(:url)[:path] || "/")}
  end

  @doc """
  Builds the script_name for caching.
  """
  def script_name(endpoint) do
    {:cache, Plug.Router.Utils.split(endpoint.config(:url)[:path] || "/")}
  end

  @doc """
  Builds the static url from its configuration.

  The result is wrapped in a `{:cache, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def static_url(endpoint) do
    url = endpoint.config(:static_url) || endpoint.config(:url)
    {:cache, build_url(endpoint, url) |> String.Chars.URI.to_string()}
  end

  @doc """
  Builds a struct url for user processing.

  The result is wrapped in a `{:cache, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def struct_url(endpoint) do
    url    = endpoint.config(:url)
    struct = build_url(endpoint, url)
    {:cache,
      case url[:path] || "/" do
        "/"  -> struct
        path -> %{struct | path: path}
      end}
  end

  defp build_url(endpoint, url) do
    build_url(endpoint.config(:https), endpoint.config(:http), url)
  end

  defp build_url(https, http, url) do
    {scheme, port} =
      cond do
        https ->
          {"https", https[:port]}
        http ->
          {"http", http[:port]}
        true ->
          {"http", 80}
      end

    scheme = url[:scheme] || scheme
    host   = host_to_binary(url[:host] || "localhost")
    port   = port_to_integer(url[:port] || port)

    %URI{scheme: scheme, port: port, host: host}
  end

  @doc """
  Returns the script path root.
  """
  def static_path(endpoint) do
    script_path = (endpoint.config(:static_url) || endpoint.config(:url))[:path] || "/"
    {:cache, empty_string_if_root(script_path)}
  end

  defp empty_string_if_root("/"), do: ""
  defp empty_string_if_root(other), do: other

  @doc """
  Returns the static path of a file in the static root directory.

  When the file exists, it includes a timestamp. When it doesn't exist,
  just the static path is returned.

  The result is wrapped in a `{:cache | :nocache, value}` tuple so
  the Phoenix.Config layer knows how to cache it.
  """
  def static_path(_endpoint, "/" <> _ = path) do
    {:nocache, path}
  end

  def static_path(_endpoint, path) when is_binary(path) do
    raise ArgumentError, "static_path/2 expects a path starting with / as argument"
  end

  # TODO v1.4: Deprecate {:system, env_var}
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host

  # TODO v1.4: Deprecate {:system, env_var}
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  @doc """
  Invoked to warm up caches on start and config change.
  """
  def warmup(endpoint) do
    endpoint.host
    endpoint.path("/")
    endpoint.script_name
    warmup_url(endpoint)
    warmup_static(endpoint)
    :ok
  rescue
    _ -> :ok
  end

  defp warmup_url(endpoint) do
    endpoint.url
    endpoint.static_url
    endpoint.struct_url
  end

  defp warmup_static(endpoint) do
    for {key, value} <- cache_static_manifest(endpoint) do
      Phoenix.Config.cache(endpoint, {:__phoenix_static__, "/" <> key}, fn _ ->
        {:cache, "/" <> value <> "?vsn=d"}
      end)
    end
    endpoint.static_path("/")
  end

  defp cache_static_manifest(endpoint) do
    if inner = endpoint.config(:cache_static_manifest) do
      outer = Application.app_dir(endpoint.config(:otp_app), inner)

      if File.exists?(outer) do
        manifest =
          outer
          |> File.read!
          |> Poison.decode!

        # TODO v1.4: No longer support old manifests
        manifest["latest"] || manifest
      else
        Logger.error "Could not find static manifest at #{inspect outer}. " <>
                     "Run \"mix phx.digest\" after building your static files " <>
                     "or remove the configuration from \"config/prod.exs\"."
      end
    else
      %{}
    end
  end
end
