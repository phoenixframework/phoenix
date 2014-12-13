defmodule Phoenix.Endpoint.Adapter do
  # This module contains the logic used by most functions in
  # Phoenix.Endpoint. Today much of the logic start/stop logic
  # is specific to cowboy but we can make it more generic when
  # we add support for other adapters.
  @moduledoc false

  @doc """
  Starts the endpoint process.
  """
  def start_link(otp_app, module) do
    Phoenix.Config.start_link(otp_app, module, defaults(otp_app, module))
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
       websocket_serializer: Phoenix.Transports.JSONSerializer
     ],

     # Runtime config
     cache_static_lookup: false,
     http: false,
     https: false,
     secret_key_base: nil,
     url: [host: "localhost"]]
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
    port   = to_string(url[:port] || port)

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
      {:ok, %File.Stat{mtime: mtime, type: type}}
          when type != :directory and is_tuple(mtime) ->
        key = if endpoint.config(:cache_static_lookup), do: :cache, else: :stale
        sec = :calendar.datetime_to_gregorian_seconds(mtime)
        {key, path <> "?" <> Integer.to_string(sec)}
      _ ->
        {:stale, path}
    end
  end

  def static_path(endpoint, path) when is_binary(path) do
    raise ArgumentError, "static_path/2 expects a path starting with / as argument"
  end

  ## Adapter specific

  @doc """
  Serves requests from the endpoint.
  """
  def serve(otp_app, module) do
    # TODO: We need to test this logic when we support custom adapters.
    if config = module.config(:http) do
      config =
        config
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4000)
      serve(:http, module, config)
    end

    if config = module.config(:https) do
      config =
        Keyword.merge(module.config(:http) || [], module.config(:https))
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4040)
      serve(:https, module, config)
    end

    :ok
  end

  defp serve(scheme, module, config) do
    opts = dispatch(module, config)
    report apply(Plug.Adapters.Cowboy, scheme, [module, [], opts]), scheme, module, opts
  end

  defp dispatch(module, config) do
    config
    |> Keyword.put(:dispatch, [{:_, [{:_, Phoenix.Endpoint.CowboyHandler, {module, []}}]}])
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
        raise "Something went wrong while starting endpoint: #{Exception.format_exit reason}"
    end
  end

  @doc """
  Stops the endpoint.
  """
  def shutdown(_otp_app, module) do
    if module.config(:http) do
      Plug.Adapters.Cowboy.shutdown(Module.concat(module, HTTP))
    end

    if module.config(:https) do
      Plug.Adapters.Cowboy.shutdown(Module.concat(module, HTTPS))
    end

    :ok
  end
end
