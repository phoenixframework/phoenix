defmodule Phoenix.Router.Adapter do
  # This module contains the logic for starting and stopping
  # the router server. Today, much of the logic is specific
  # to cowboy but we can make it more generic when we add
  # support for other adapters.
  @moduledoc false

  @doc """
  The router configuration used at compile time.
  """
  def config(router) do
    config = Application.get_env(:phoenix, router, [])

    otp_app = cond do
      config[:otp_app] ->
        config[:otp_app]
      Code.ensure_loaded?(Mix.Project) && Mix.Project.config[:app] ->
        Mix.Project.config[:app]
      true ->
        raise "please set :otp_app config for #{inspect router}"
    end

    Phoenix.Config.merge(defaults(otp_app, router), config)
  end

  @doc """
  Starts the router.
  """
  def start(otp_app, module) do
    Phoenix.Config.start_supervised(module, defaults(otp_app, module))

    # TODO: We need to test this logic when we support custom adapters.
    if config = module.config(:http) do
      config =
        config
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4000)
      start(:http, module, config)
    end

    if config = module.config(:https) do
      config =
        Keyword.merge(module.config(:http) || [], module.config(:https))
        |> Keyword.put_new(:otp_app, otp_app)
        |> Keyword.put_new(:port, 4040)
      start(:https, module, config)
    end

    :ok
  end

  defp start(scheme, module, config) do
    opts = dispatch(module, config)
    report apply(Plug.Adapters.Cowboy, scheme, [module, [], opts]), scheme, module, opts
  end

  defp dispatch(module, config) do
    config
    |> Keyword.put(:dispatch, [{:_, [{:_, Phoenix.Router.CowboyHandler, {module, []}}]}])
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
        raise "Something went wrong while starting router: #{Exception.format_exit reason}"
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
    :ok
  end

  defp defaults(otp_app, module) do
    [otp_app: otp_app,

     # Compile-time config
     parsers: [parsers: [:urlencoded, :multipart, :json],
               pass: ["*/*"], json_decoder: Poison],
     static: [at: "/"],
     session: false,

     # Transports
     transports: [longpoller: [window_ms: 10_000]],

     # Runtime config
     url: [host: "localhost"],
     http: false,
     https: false,
     secret_key_base: nil,
     debug_errors: false,
     render_errors: render_errors(module)]
  end

  defp render_errors(module) do
    module
    |> Module.split
    |> Enum.at(0)
    |> Module.concat("ErrorsView")
  end
end
