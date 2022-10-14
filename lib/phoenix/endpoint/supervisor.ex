defmodule Phoenix.Endpoint.Supervisor do
  # This module contains the logic used by most functions in Phoenix.Endpoint
  # as well the supervisor for sockets, adapters, watchers, etc.
  @moduledoc false

  require Logger
  use Supervisor

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, mod, opts \\ []) do
    with {:ok, pid} = ok <- Supervisor.start_link(__MODULE__, {otp_app, mod, opts}, name: mod) do
      # We don't use the defaults in the checks below
      conf = Keyword.merge(Application.get_env(otp_app, mod, []), opts)
      warmup(mod)
      log_access_url(mod, conf)
      browser_open(mod, conf)

      measurements = %{system_time: System.system_time()}
      metadata = %{pid: pid, config: conf, module: mod, otp_app: otp_app}
      :telemetry.execute([:phoenix, :endpoint, :init], measurements, metadata)

      ok
    end
  end

  @doc false
  def init({otp_app, mod, opts}) do
    default_conf = Phoenix.Config.merge(defaults(otp_app, mod), opts)
    env_conf = config(otp_app, mod, default_conf)

    secret_conf =
      case mod.init(:supervisor, env_conf) do
        {:ok, init_conf} ->
          if is_nil(Application.get_env(otp_app, mod)) and init_conf == env_conf do
            Logger.warning("no configuration found for otp_app #{inspect(otp_app)} and module #{inspect(mod)}")
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

    if conf[:instrumenters] do
      Logger.warning(":instrumenters configuration for #{inspect(mod)} is deprecated and has no effect")
    end

    if server? and conf[:code_reloader] do
      Phoenix.CodeReloader.Server.check_symlinks()
    end

    # TODO: Remove this once {:system, env_var} tuples are removed
    warn_on_deprecated_system_env_tuples(otp_app, mod, conf, :http)
    warn_on_deprecated_system_env_tuples(otp_app, mod, conf, :https)
    warn_on_deprecated_system_env_tuples(otp_app, mod, conf, :url)
    warn_on_deprecated_system_env_tuples(otp_app, mod, conf, :static_url)

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
      Logger.warning """
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
      adapter = config[:adapter] || Phoenix.Endpoint.Cowboy2Adapter
      adapter.child_specs(mod, config)
    else
      []
    end
  end

  defp watcher_children(_mod, conf, server?) do
    if server? || conf[:force_watchers] do
      Enum.map(conf[:watchers], &{Phoenix.Endpoint.Watcher, &1})
    else
      []
    end
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
    server?(Application.get_env(otp_app, endpoint, []))
  end

  defp server?(conf) when is_list(conf) do
    Keyword.get_lazy(conf, :server, fn ->
      Application.get_env(:phoenix, :serve_endpoints, false)
    end)
  end

  defp defaults(otp_app, module) do
    [
      otp_app: otp_app,

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
      # TODO: Gettext had a compiler in earlier versions,
      # but not since v0.20, so we can remove it here eventually.
      reloadable_compilers: [:gettext, :elixir, :app],
      secret_key_base: nil,
      static_url: nil,
      url: [host: "localhost", path: "/"],
      cache_manifest_skip_vsn: false,

      # Supervisor config
      watchers: [],
      force_watchers: false
   ]
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
      Logger.warning("url: [host: ...] configuration value #{inspect(host)} for #{inspect(endpoint)} is invalid")
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

  # TODO: Remove the first function clause once {:system, env_var} tuples are removed
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host

  # TODO: Remove the first function clause once {:system, env_var} tuples are removed
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  defp warn_on_deprecated_system_env_tuples(otp_app, mod, conf, key) do
    deprecated_configs = Enum.filter(conf[key] || [], &match?({_, {:system, _}}, &1))

    if Enum.any?(deprecated_configs) do
      deprecated_config_lines = for {k, v} <- deprecated_configs, do: "#{k}: #{inspect(v)}"
      runtime_exs_config_lines = for {key, {:system, env_var}} <- deprecated_configs, do: ~s|#{key}: System.get_env("#{env_var}")|

      Logger.warning """
      #{inspect(key)} configuration containing {:system, env_var} tuples for #{inspect(mod)} is deprecated.

      Configuration with deprecated values:

          config #{inspect(otp_app)}, #{inspect(mod)},
            #{key}: [
              #{deprecated_config_lines |> Enum.join(",\r\n        ")}
            ]

      Move this configuration into config/runtime.exs and replace the {:system, env_var} tuples
      with System.get_env/1 function calls:

          config #{inspect(otp_app)}, #{inspect(mod)},
            #{key}: [
              #{runtime_exs_config_lines |> Enum.join(",\r\n        ")}
            ]
      """
    end
  end

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
    with_vsn? = !endpoint.config(:cache_manifest_skip_vsn)

    Enum.each(latest, fn {key, _} ->
      Phoenix.Config.cache(endpoint, {:__phoenix_static__, "/" <> key}, fn _ ->
        {:cache, static_cache(digests, Map.get(latest, key), with_vsn?)}
      end)
    end)
  end

  defp warmup_static(_endpoint, _manifest) do
    raise ArgumentError, "expected warmup_static/2 to include 'latest' and 'digests' keys in manifest"
  end

  defp static_cache(digests, value, true) do
    {"/#{value}?vsn=d", static_integrity(digests[value]["sha512"])}
  end

  defp static_cache(digests, value, false) do
    {"/#{value}", static_integrity(digests[value]["sha512"])}
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
                     "or remove the \"cache_static_manifest\" configuration from your config files."
      end
    else
      %{}
    end
  end

  defp log_access_url(endpoint, conf) do
    if Keyword.get(conf, :log_access_url, true) && server?(conf) do
      Logger.info("Access #{inspect(endpoint)} at #{endpoint.url()}")
    end
  end

  defp browser_open(endpoint, conf) do
    if Application.get_env(:phoenix, :browser_open) && server?(conf) do
      url = endpoint.url()

      {cmd, args} =
        case :os.type() do
          {:win32, _} -> {"cmd", ["/c", "start", url]}
          {:unix, :darwin} -> {"open", [url]}
          {:unix, _} -> {"xdg-open", [url]}
        end

      System.cmd(cmd, args)
    end
  end
end
