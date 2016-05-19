defmodule Phoenix.Endpoint.Server do
  # The supervisor for the underlying handlers.
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(otp_app, endpoint, opts \\ []) do
    Supervisor.start_link(__MODULE__, {otp_app, endpoint}, opts)
  end

  def init({otp_app, endpoint}) do
    handler  = endpoint.config(:handler)
    children =
      for {scheme, port} <- [http: 4000, https: 4040],
          config = endpoint.config(scheme) do
        handler.child_spec(scheme, endpoint, default(config, otp_app, port))
      end
    supervise(children, strategy: :one_for_one)
  end

  defp default(config, otp_app, port) do
    config =
      config
      |> Keyword.put_new(:otp_app, otp_app)
      |> Keyword.put_new(:port, port)

    Keyword.put(config, :port, to_port(config[:port]))
  end

  defp to_port(nil), do: raise "server can't start because :port in config is nil, please use a valid port number"
  defp to_port(binary)  when is_binary(binary), do: String.to_integer(binary)
  defp to_port(integer) when is_integer(integer), do: integer
  defp to_port({:system, env_var}), do: to_port(System.get_env(env_var))
end
