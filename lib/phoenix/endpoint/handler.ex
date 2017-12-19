defmodule Phoenix.Endpoint.Handler do
  @moduledoc """
  API for exporting a webserver.

  A handler will need to implement a `child_spec/3` function which takes:

    * the scheme of the endpoint :http or :https
    * phoenix top-most endpoint module
    * phoenix app configuration for the specified scheme

  It has to return a supervisor child specification.
  """

  @doc """
  Provides a server child specification to be started under the endpoint.
  """
  @callback child_spec(scheme :: atom, endpoint :: module, config :: Keyword.t) :: Supervisor.Spec.spec

  alias Phoenix.Endpoint.{CowboyHandler, Cowboy2Handler}

  use Supervisor
  require Logger

  @doc false
  def start_link(otp_app, endpoint, opts \\ []) do
    Supervisor.start_link(__MODULE__, {otp_app, endpoint}, opts)
  end

  @doc false
  def init({otp_app, endpoint}) do
    user_handler = endpoint.config(:handler)
    autodetected_handler = cowboy_version_handler()
    warn_on_different_handler_version(user_handler, autodetected_handler, endpoint)
    handler = user_handler || autodetected_handler

    children =
      for {scheme, port} <- [http: 4000, https: 4040],
          config = endpoint.config(scheme) do
        handler.child_spec(scheme, endpoint, default(config, otp_app, port))
      end
    supervise(children, strategy: :one_for_one)
  end

  defp default(config, otp_app, port) when is_list(config) do
    {config_keywords, config_other} = Enum.split_with(config, &keyword_item?/1)

    config_keywords =
      config_keywords
      |> Keyword.put_new(:otp_app, otp_app)
      |> Keyword.put_new(:port, port)

    config_keywords
    |> Keyword.put(:port, to_port(config_keywords[:port]))
    |> Kernel.++(config_other)
  end

  defp keyword_item?({key, _}) when is_atom(key), do: true
  defp keyword_item?(_), do: false

  # TODO v1.4: Deprecate {:system, env_var}
  defp to_port(nil), do: raise "server can't start because :port in config is nil, please use a valid port number"
  defp to_port(binary)  when is_binary(binary), do: String.to_integer(binary)
  defp to_port(integer) when is_integer(integer), do: integer
  defp to_port({:system, env_var}), do: to_port(System.get_env(env_var))

  defp cowboy_version_handler() do
    case Application.spec(:cowboy, :vsn) do
      [?1 | _] -> CowboyHandler
      _ -> Cowboy2Handler
    end
  end

  defp warn_on_different_handler_version(CowboyHandler, Cowboy2Handler, endpoint) do
    Logger.warn("""
    You have specified #{inspect CowboyHandler} for Cowboy v1.x \
    in the :handler configuration of your Phoenix endpoint #{inspect endpoint} \
    but your mix.exs has fetched Cowboy v2.x.

    If you wish to use Cowboy 1, please update mix.exs to point to the \
    correct Cowboy version:

        {:cowboy, "~> 1.0"}

    If you want to use Cowboy 2, then please remove the :handler option \
    in your config.exs file or set it to:

        handler: Phoenix.Endpoint.Cowboy2Handler

    """)

    raise "aborting due to handler mismatch"
  end
  defp warn_on_different_handler_version(_user, _autodetected, _endpoint), do: nil
end
