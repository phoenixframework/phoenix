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

  use Supervisor
  require Logger

  @doc false
  def start_link(otp_app, endpoint, opts \\ []) do
    Supervisor.start_link(__MODULE__, {otp_app, endpoint}, opts)
  end

  @doc false
  def init({otp_app, endpoint}) do
    handler  = endpoint.config(:handler)
    children =
      for {scheme, port} <- [http: 4000, https: 4040],
          config = endpoint.config(scheme) do
        handler.child_spec(scheme, endpoint, default(config, otp_app, port))
      end
    supervise(children, strategy: :one_for_one)
  end

  defp default(config, otp_app, port) when is_list(config) do
    {config_keywords, config_other} = Enum.partition(config, &keyword_item?/1)

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
end
