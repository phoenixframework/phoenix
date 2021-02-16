defmodule Phoenix.Endpoint.Supervisor do
  # This module contains the logic used by most functions in Phoenix.Endpoint
  # as well the supervisor for sockets, adapters, watchers, etc.
  @moduledoc false

  require Logger
  use Supervisor
  alias Phoenix.Endpoint.{CowboyAdapter, Cowboy2Adapter}

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, mod, opts \\ []) do
    case Supervisor.start_link(__MODULE__, {otp_app, mod, opts}, name: mod) do
      {:ok, _} = ok ->
        warmup(mod)
        log_access_url(otp_app, mod, opts)
        ok

      {:error, _} = error ->
        error
    end
  end

  defp check_compile_configs!(mod, runtime_configs) do
    compile_configs = mod.__compile_config__()

    bad_keys =
      Enum.filter(Phoenix.Endpoint.Supervisor.compile_config_keys(), fn key ->
        compile_config = Keyword.get(compile_configs, key)
        runtime_config = Keyword.get(runtime_configs, key)

        if compile_config != runtime_config do
          require Logger

          Logger.error("""
          #{inspect(key)} mismatch for #{inspect(mod)}.

          Compile time configuration: #{inspect(compile_config)}
          Runtime configuration     : #{inspect(runtime_config)}

          #{inspect(key)} is a compile-time configuration, so setting
          it at runtime has no effect. Therefore you must set it in your
          config/prod.exs or similar (not in your config/releases.exs)
          and make sure the value doesn't change.
          """)

          true
        else
          false
        end
      end)

    unless Enum.empty?(bad_keys) do
      raise ArgumentError,
            "expected these options to be unchanged from compile time: #{inspect(bad_keys)}"
    end

    :ok
  end

  @doc false
  def init({otp_app, mod, opts}) do
    default_conf = Phoenix.Config.merge(defaults(otp_app, mod), opts)
    env_conf = config(otp_app, mod, default_conf)

    secret_conf =
      case mod.init(:supervisor, env_conf) do
        {:ok, init_conf} ->
          if is_nil(Application.get_env(otp_app, mod)) and init_conf == env_conf do
            Logger.warn("no configuration found for otp_app #{inspect(otp_app)} and module #{inspect(mod)}")
          end

          init_conf

        other ->
          raise ArgumentError, "expected init/2 callback to return {:ok, config}, got: #{inspect other}"
      end

    extra_conf = [
      endpoint_id: :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false),
      # TODO: Remove this once :pubsub is removed
      pubsub_server: secret_conf[:pubsub_server] || secret_conf[:pubsub][:name]
    ]

    secret_conf = extra_conf ++ secret_conf
    default_conf = extra_conf ++ default_conf

    # Drop all secrets from secret_conf before passing it around
    conf = Keyword.drop(secret_conf, [:secret_key_base])
    server? = server?(conf)
    check_compile_configs!(mod, conf)

    if conf[:instrumenters] do
      Logger.warn(":instrumenters configuration for #{inspect(mod)} is deprecated and has no effect")
    end

    if server? and conf[:code_reloader] do
      Phoenix.CodeReloader.Server.check_symlinks()
    end

    children =
      config_children(mod, secret_conf, default_conf) ++
      pubsub_children(mod, conf) ++
      socket_children(mod) ++
      server_children(mod, conf, server?) ++
      watcher_children(mod, conf, server?)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp pubsub_children(mod, conf) do
    pub_conf = conf[:pubsub]

    if pub_conf do
      Logger.warn """
      The :pubsub key in your #{inspect mod} is deprecated.

      You must now start the pubsub in your application supervision tree.
      Go to lib/my_app/application.ex and add the following:

          {Phoenix.PubSub, #{inspect pub_conf}}

      Now, back in your config files in config/*, you can remove the :pubsub
      key and add the :pubsub_server key, with the PubSub name:

          pubsub_server: #{inspect pub_conf[:name]}
      """
    end

    if pub_conf[:adapter] do
      [{Phoenix.PubSub, pub_conf}]
    else
      []
    end
  end

  defp socket_children(endpoint) do
    endpoint.__sockets__
    |> Enum.uniq_by(&elem(&1, 1))
    |> Enum.map(fn {_, socket, opts} -> socket.child_spec([endpoint: endpoint] ++ opts) end)
  end

  defp config_children(mod, conf, default_conf) do
    args = {mod, conf, default_conf, name: Module.concat(mod, "Config")}
    [{Phoenix.Config, args}]
  end

  defp server_children(mod, config, server?) do
    if server? do
      user_adapter = user_adapter(mod, config)
      autodetected_adapter = cowboy_version_adapter()
      warn_on_different_adapter_version(user_adapter, autodetected_adapter, mod)
      (user_adapter || autodetected_adapter).child_specs(mod, config)
    else
      []
    end
  end

  defp user_adapter(endpoint, config) do
    case config[:handler] do
      nil ->
        config[:adapter]

      Phoenix.Endpoint.CowboyHandler ->
        Logger.warn "Phoenix.Endpoint.CowboyHandler is deprecated, please use Phoenix.Endpoint.CowboyAdapter instead"
        CowboyAdapter

      other ->
        Logger.warn "The :handler option in #{inspect endpoint} is deprecated, please use :adapter instead"
        other
    end
  end

  defp cowboy_version_adapter() do
    case Application.spec(:cowboy, :vsn) do
      [?1 | _] -> CowboyAdapter
      _ -> Cowboy2Adapter
    end
  end

  defp warn_on_different_adapter_version(CowboyAdapter, Cowboy2Adapter, endpoint) do
    Logger.error("""
    You have specified #{inspect CowboyAdapter} for Cowboy v1.x \
    in the :adapter configuration of your Phoenix endpoint #{inspect endpoint} \
    but your mix.exs has fetched Cowboy v2.x.

    If you wish to use Cowboy 1, please update mix.exs to point to the \
    correct Cowboy version:

        {:plug_cowboy, "~> 1.0"}

    If you want to use Cowboy 2, then please remove the :adapter option \
    in your config.exs file or set it to:

        adapter: Phoenix.Endpoint.Cowboy2Adapter

    """)

    raise "aborting due to adapter mismatch"
  end
  defp warn_on_different_adapter_version(_user, _autodetected, _endpoint), do: :ok

  defp watcher_children(_mod, conf, server?) do
    if server? do
      Enum.map(conf[:watchers], fn {cmd, args} ->
        {Phoenix.Endpoint.Watcher, watcher_args(cmd, args)}
      end)
    else
      []
    end
  end

  defp watcher_args(cmd, cmd_args) do
    {args, opts} = Enum.split_while(cmd_args, &is_binary(&1))
    {cmd, args, opts}
  end

  @doc """
  The endpoint configuration used at compile time.
  """
  def config(otp_app, endpoint) do
    config(otp_app, endpoint, defaults(otp_app, endpoint))
  end

  defp config(otp_app, endpoint, defaults) do
    Phoenix.Config.from_env(otp_app, endpoint, defaults)
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

     # Compile-time config
     code_reloader: false,
     debug_errors: false,
     render_errors: [view: render_errors(module), accepts: ~w(html), layout: false],

     # Runtime config
     cache_static_manifest: nil,
     check_origin: true,
     http: false,
     https: false,
     reloadable_apps: nil,
     reloadable_compilers: [:gettext, :phoenix, :elixir],
     secret_key_base: nil,
     static_url: nil,
     url: [host: "localhost", path: "/"],

     # Supervisor config
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
  the `Phoenix.Config` layer knows how to cache it.
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
    {:cache, String.split(endpoint.config(:url)[:path] || "/", "/", trim: true)}
  end

  @doc """
  Builds the static url from its configuration.

  The result is wrapped in a `{:cache, value}` tuple so
  the `Phoenix.Config` layer knows how to cache it.
  """
  def static_url(endpoint) do
    url = endpoint.config(:static_url) || endpoint.config(:url)
    {:cache, build_url(endpoint, url) |> String.Chars.URI.to_string()}
  end

  @doc """
  Builds a struct url for user processing.

  The result is wrapped in a `{:cache, value}` tuple so
  the `Phoenix.Config` layer knows how to cache it.
  """
  def struct_url(endpoint) do
    url = endpoint.config(:url)
    {:cache, build_url(endpoint, url)}
  end

  defp build_url(endpoint, url) do
    https = endpoint.config(:https)
    http  = endpoint.config(:http)

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

    if host =~ ~r"[^:]:\d" do
      Logger.warn("url: [host: ...] configuration value #{inspect(host)} for #{inspect(endpoint)} is invalid")
    end

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
  Returns a two item tuple with the first element containing the
  static path of a file in the static root directory
  and the second element containing the sha512 of that file (for SRI).

  When the file exists, it includes a timestamp. When it doesn't exist,
  just the static path is returned.

  The result is wrapped in a `{:cache | :nocache, value}` tuple so
  the `Phoenix.Config` layer knows how to cache it.
  """
  @invalid_local_url_chars ["\\"]

  def static_lookup(_endpoint, "//" <> _ = path) do
    raise_invalid_path(path)
  end

  def static_lookup(_endpoint, "/" <> _ = path) do
    if String.contains?(path, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for path #{inspect path}"
    else
      {:nocache, {path, nil}}
    end
  end

  def static_lookup(_endpoint, path) when is_binary(path) do
    raise_invalid_path(path)
  end

  defp raise_invalid_path(path) do
    raise ArgumentError, "expected a path starting with a single / but got #{inspect path}"
  end

  # TODO: Deprecate {:system, env_var} once we require Elixir v1.9+
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host

  # TODO: Deprecate {:system, env_var} once we require Elixir v1.9+
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  @doc """
  Invoked to warm up caches on start and config change.
  """
  def warmup(endpoint) do
    endpoint.host()
    endpoint.script_name()
    endpoint.path("/")
    warmup_url(endpoint)
    warmup_static(endpoint)
    :ok
  rescue
    _ -> :ok
  end

  defp warmup_url(endpoint) do
    endpoint.url()
    endpoint.static_url()
    endpoint.struct_url()
  end

  defp warmup_static(endpoint) do
    warmup_static(endpoint, cache_static_manifest(endpoint))
    endpoint.static_path("/")
  end

  defp warmup_static(endpoint, %{"latest" => latest, "digests" => digests}) do
    Phoenix.Config.put_new(endpoint, :cache_static_manifest_latest, latest)

    Enum.each(latest, fn {key, _} ->
      Phoenix.Config.cache(endpoint, {:__phoenix_static__, "/" <> key}, fn _ ->
        {:cache, static_cache(digests, Map.get(latest, key))}
      end)
    end)
  end

  defp warmup_static(_endpoint, _manifest) do
    raise ArgumentError, "expected warmup_static/2 to include 'latest' and 'digests' keys in manifest"
  end

  defp static_cache(digests, value) do
    {"/#{value}?vsn=d", static_integrity(digests[value]["sha512"])}
  end

  defp static_integrity(nil), do: nil
  defp static_integrity(sha), do: "sha512-#{sha}"

  defp cache_static_manifest(endpoint) do
    if inner = endpoint.config(:cache_static_manifest) do
      {app, inner} =
        case inner do
          {_, _} = inner -> inner
          inner when is_binary(inner) -> {endpoint.config(:otp_app), inner}
          _ -> raise ArgumentError, ":cache_static_manifest must be a binary or a tuple"
        end

      outer = Application.app_dir(app, inner)

      if File.exists?(outer) do
        outer |> File.read!() |> Phoenix.json_library().decode!()
      else
        Logger.error "Could not find static manifest at #{inspect outer}. " <>
                     "Run \"mix phx.digest\" after building your static files " <>
                     "or remove the configuration from \"config/prod.exs\"."
      end
    else
      %{}
    end
  end

  defp log_access_url(otp_app, endpoint, opts) do
    if Keyword.get(opts, :log_access_url, true) && Phoenix.Endpoint.server?(otp_app, endpoint) do
      Logger.info("Access #{inspect(endpoint)} at #{endpoint.url()}")
    end
  end

  @doc """
  List of keys which we ensure are unchanged from compile time to runtime. For
  example, the :force_ssl option must be available at compile time in order to
  work properly. We check these keys so we can warn the user that changing the
  option at runtime may lead to undesirable behavior.
  """
  def compile_config_keys do
    [:force_ssl]
  end
end
